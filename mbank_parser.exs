Mix.install(
  [
    {:csv, "~> 3.0"},
    {:iconv, "~> 1.0.10"}
  ],
  verbose: true
)

defmodule MbankParser do
  @moduledoc """
  Parses an mBank CSV file and saves a processed version of the file

  ## Examples

      iex> MbankParser.process("example.csv")

  """

  @doc """
  supported_operations = [
    "PRZELEW REGULARNE OSZCZ",
    "PRZELEW NA TWOJE CELE",
    "RĘCZNA SPŁATA KARTY KREDYT.",
    "KAPITALIZACJA ODSETEK",
    "PODATEK OD ODSETEK KAPITAŁOWYCH",
    "PRZELEW WŁASNY",
    "PRZELEW WEWNĘTRZNY PRZYCHODZĄCY"
  ]
  """

  @ynab_headers ~w(date memo payee amount)a
  @ynab_filename_prefix "eYNAB_ready_"

  def process(file_path) do
    file = file_path |> File.stream!()

    # maybe use it for new file path: eYNAB_ready_ekonto_2022-02-11.csv
    account_id = find_account_id(file)

    file
    |> drop_metadata()
    |> prepare_data(account_id)
    |> save_to_file(file_path)

    IO.puts("Parsing complete")
  end

  defp prepare_data(stream, account_id) do
    stream
    |> CSV.decode!(separator: ?;, field_transform: &to_unicode/1)
    |> Stream.map(&serialize(account_id, &1))
    |> CSV.encode(
      headers: @ynab_headers,
      separator: ?,,
      delimeter: "\r\n"
    )
    |> Enum.to_list()
  end

  defp save_to_file(data, file_path) do
    file_name = @ynab_filename_prefix <> Path.basename(file_path)
    full_path = Path.join(Path.dirname(file_path), file_name)

    File.write!(full_path, data)
    IO.puts("File saved as #{file_name}")
  end

  defp serialize(_parent_account_id, transaction) do
    # Column names from the CSV file
    [_, data_operacji, opis_operacji, tytul, nadawca_odbiorca, numer_konta, kwota, _, _] =
      transaction

    %{date: date, memo: memo, payee: payee, amount: amount} =
      serialized_data =
      %{
        date: data_operacji,
        operation: opis_operacji,
        memo: sanitize(tytul),
        payee: sanitize(nadawca_odbiorca),
        account_number: sanitize(numer_konta),
        amount: format_number(kwota)
      }
      |> prefill_ynab_fields()
      |> transform_operation()
      |> Map.take([:date, :memo, :payee, :amount])

    # print result to terminal
    [date, memo, payee, amount] |> Enum.join(", ") |> IO.puts()

    serialized_data
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

  # @other_operations [
  #   "BLIK ZAKUP E-COMMERCE",
  #   "BLIK P2P-PRZYCHODZĄCY",
  #   "BLIK P2P-WYCHODZĄCY",
  #   "ZAKUP PRZY UŻYCIU KARTY"
  # ]

  defp transform_operation(%{operation: opis_operacji} = transaction)
       when opis_operacji in @internal_account_operations do
    transform_internal(transaction, transaction.account_number)
  end

  defp transform_operation(%{operation: opis_operacji} = transaction)
       when opis_operacji in @interest_operations do
    Map.merge(transaction, %{payee: transaction.operation})
  end

  defp transform_operation(%{operation: "PRZELEW NA TWOJE CELE"} = transaction) do
    transform_internal(transaction, transaction.operation)
  end

  defp transform_operation(
         %{operation: "RĘCZNA SPŁATA KARTY KREDYT.", payee: card_id} = transaction
       ) do
    transform_internal(transaction, card_id)
  end

  defp transform_operation(transaction), do: transaction

  defp transform_internal(transaction, account_id) do
    accounts()
    |> Enum.find(&String.contains?(account_id, &1.id))
    |> case do
      %{id: _, name: account_name} ->
        Map.merge(transaction, %{payee: format_transfer(account_name)})

      _other ->
        IO.puts("Unknown account: #{account_id}")
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

  # defp accounts do
  #   [
  #     %{id: "", name: "Ekonto"}
  #   ]
  # end

  defp accounts(), do: []

  # Helpers

  # CSV file is Windows-encoded, conversion is needed to keep the special characters
  # Check if https://hexdocs.pm/codepagex/Codepagex.html#encoding_list/1 would work
  # VENDORS/MICSFT/WINDOWS/CP1250
  defp to_unicode(row) do
    :iconv.convert("CP1250", "UTF-8", row)
  end

  defp find_account_id(stream) do
    stream
    |> Stream.with_index()
    |> Stream.filter(fn {_, index} -> index == 20 end)
    |> Stream.map(fn {line, _} -> line end)
    |> CSV.decode!(separator: ?;, field_transform: &to_unicode/1)
    |> Enum.take(1)
    |> List.first()
    |> :unicode.characters_to_binary()
    |> format_number()
  end

  defp drop_metadata(stream) do
    stream
    |> Stream.drop(38)
    |> Stream.drop(-5)
  end

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

  defp format_transfer(account_name), do: "Transfer: " <> account_name
end

# Call the function with the provided file path
System.argv() |> List.first() |> MbankParser.process()
# MbankParser.process(input_file_path)

# elixir mbank_parser.exs path/to/your/input.csv
