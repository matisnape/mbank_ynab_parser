Mix.install(
  [
    {:csv, "~> 3.0"},
    {:iconv, "~> 1.0.12"}
  ],
  verbose: true
)

defmodule BankParser do
  @moduledoc """
  Parses bank CSV files (mBank and ING) and saves a processed version of the file
  """

  @ynab_headers ~w(date memo payee amount saldo)a
  @ynab_filename_prefix "eYNAB_ready_"

  def process(file_path) do
    file = File.stream!(file_path)
    bank_type = detect_bank_type(file)

    file
    |> drop_metadata(bank_type)
    |> prepare_data(bank_type)
    |> save_to_file(file_path)

    IO.puts("Parsing complete for #{bank_type} file")
  end

  defp detect_bank_type(stream) do
    first_line =
      stream
      |> Stream.take(1)
      |> Enum.at(0)
      |> to_unicode()

    cond do
      String.contains?(first_line, "mBank") -> :mbank
      String.contains?(first_line, "ING") -> :ing
      true -> raise "Unknown bank type. First line should contain 'mBank' or 'ING'"
    end
  end

  defp drop_metadata(stream, :mbank) do
    stream
    |> Stream.drop(38)
    |> Stream.drop(-5)
  end

  defp drop_metadata(stream, :ing) do
    stream
    |> Stream.drop(19)
    |> Stream.drop(-3)
  end

  defp prepare_data(stream, bank_type) do
    stream
    |> CSV.decode!(separator: ?;, field_transform: &to_unicode/1, escape_character: 0)
    |> Stream.map(&parse_transaction(bank_type, &1))
    |> CSV.encode(
      headers: @ynab_headers,
      separator: ?,,
      delimeter: "\r\n"
    )
    |> Enum.to_list()
  end

  defp parse_transaction(:mbank, transaction) do
    case transaction do
      [_, data_operacji, opis_operacji, tytul, nadawca_odbiorca, numer_konta, kwota, saldo, _] ->
        %{
          date: data_operacji,
          operation: opis_operacji,
          memo: sanitize(tytul),
          payee: sanitize(nadawca_odbiorca),
          account_number: sanitize(numer_konta),
          amount: format_number(kwota),
          saldo: format_number(saldo)
        }

      [_, data_operacji, opis_operacji, tytul, _, nadawca_odbiorca, numer_konta, kwota, saldo, _] ->
        %{
          date: data_operacji,
          operation: opis_operacji,
          memo: sanitize(tytul),
          payee: sanitize(nadawca_odbiorca),
          account_number: sanitize(numer_konta),
          amount: format_number(kwota),
          saldo: format_number(saldo)
        }
    end
    |> prefill_ynab_fields()
    |> transform_operation()
    |> Map.take([:date, :memo, :payee, :amount, :saldo])
  end

  defp parse_transaction(:ing, transaction) do
    [data_transakcji, _2, dane_kontrahenta, tytul, nr_rachunku, _6, szczegoly, _8, kwota, _9 | _] =
      transaction

    %{
      date: data_transakcji,
      operation: String.trim(szczegoly),
      memo: sanitize(tytul),
      payee: sanitize(dane_kontrahenta),
      account_number: sanitize(nr_rachunku),
      amount: format_number(kwota)
    }
    |> prefill_ynab_fields()
    |> transform_operation()
    |> Map.take([:date, :memo, :payee, :amount])
  end

  defp save_to_file(data, file_path) do
    file_name = @ynab_filename_prefix <> Path.basename(file_path)
    full_path = Path.join(Path.dirname(file_path), file_name)

    File.write!(full_path, data)
    IO.puts("File saved as #{file_name}")
  end

  defp to_unicode(row) do
    :iconv.convert("CP1250", "UTF-8", row)
  end

  @internal_account_operations [
    "PRZELEW WŁASNY",
    "PRZELEW WEWNĘTRZNY PRZYCHODZĄCY",
    "PRZELEW REGULARNE OSZCZ"
  ]

  @interest_operations [
    "KAPITALIZACJA ODSETEK",
    "PODATEK OD ODSETEK KAPITAŁOWYCH"
  ]

  defp transform_operation(
         %{operation: "PRZELEW", account_number: account_id, amount: amount} = transaction
       )
       when is_binary(account_id) do
    transform_ing(transaction, account_id, amount)
  end

  defp transform_operation(%{operation: opis_operacji} = transaction)
       when opis_operacji in @internal_account_operations do
    transform_internal(transaction, transaction.account_number, transaction.amount)
  end

  defp transform_operation(%{operation: opis_operacji} = transaction)
       when opis_operacji in @interest_operations do
    Map.merge(transaction, %{payee: transaction.operation})
  end

  defp transform_operation(%{operation: "PRZELEW NA TWOJE CELE"} = transaction) do
    transform_internal(transaction, transaction.operation, transaction.amount)
  end

  defp transform_operation(
         %{operation: "RĘCZNA SPŁATA KARTY KREDYT.", payee: card_id} = transaction
       ) do
    transform_internal(transaction, card_id, transaction.amount)
  end

  defp transform_operation(%{operation: operation} = transaction) do
    Map.merge(transaction, %{payee: operation})
  end

  defp transform_internal(transaction, account_id, amount) do
    accounts()
    |> Enum.find(fn account ->
      String.contains?(account_id, account.id) or
        (transaction.operation == "PRZELEW NA TWOJE CELE" and
           account.id == "PRZELEW NA TWOJE CELE")
    end)
    |> case do
      %{id: _, name: account_name} ->
        Map.merge(transaction, %{payee: format_transfer(account_name, amount)})

      _other ->
        IO.inspect(["Unknown account: #{account_id} for transaction", transaction])
        transaction
    end
  end

  defp transform_ing(transaction, account_id, amount) do
    accounts()
    |> Enum.find(&String.contains?(account_id, &1.id))
    |> case do
      %{id: _, name: account_name} ->
        Map.merge(transaction, %{payee: format_transfer(account_name, amount)})

      _other ->
        transaction
    end
  end

  defp prefill_ynab_fields(transaction) do
    transaction
    |> populate_payee_if_empty()
    |> merge_accountid_with_memo()
  end

  defp populate_payee_if_empty(row) do
    case row do
      %{payee: "", memo: memo} -> Map.merge(row, %{payee: memo, memo: ""})
      _ -> row
    end
  end

  defp merge_accountid_with_memo(row) do
    case row do
      %{account_number: ""} ->
        row

      %{account_number: numer_konta, memo: memo} ->
        Map.merge(row, %{memo: "#{memo} #{numer_konta}"})
    end
  end

  # Prepare an enum of accounts to be used for mapping.
  # The account name should be the same as in YNAB

  defp accounts do
    [
      %{id: "", name: "Ekonto"}
    ]
  end

  defp accounts(), do: []

  defp format_number(number) do
    number
    |> String.replace(",", ".")
    |> String.replace(" ", "")
    |> String.trim()
  end

  defp sanitize(string) do
    boring_strings = [
      "'",
      "\""
    ]

    string
    |> String.replace(boring_strings, "")
    |> String.split()
    |> Enum.join(" ")
  end

  defp format_transfer(account_name, "-" <> _rest), do: "Transfer: " <> account_name
  defp format_transfer(account_name, _amount), do: "Transfer from: " <> account_name
end

# Call the function with the provided file path
System.argv() |> List.first() |> BankParser.process()

# elixir bank_parser.exs path/to/your/input.csv
