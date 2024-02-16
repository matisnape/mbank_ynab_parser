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
  @ynab_filename_prefix "YNAB_ready_"

  def process(file_path) do
    file = file_path |> File.stream!()

    account_id =
      file
      |> Stream.with_index()
      |> Stream.filter(fn {_, index} -> index == 20 end)
      |> Stream.map(fn {line, _} -> line end)
      |> CSV.decode!(separator: ?;, field_transform: &to_unicode/1)
      |> Enum.take(1)
      |> List.first()
      |> :unicode.characters_to_binary()
      |> format_number()

    file
    |> drop_metadata()
    |> CSV.decode!(separator: ?;, field_transform: &to_unicode/1)
    |> Stream.map(&serialize(account_id, &1))
    |> CSV.encode(
      headers: @ynab_headers,
      separator: ?,,
      delimeter: "\r\n"
    )
    |> Enum.to_list()
    |> write_file(file_path)
  end

  defp write_file(data, file_path) do
    file_name = @ynab_filename_prefix <> Path.basename(file_path)
    full_path = Path.join(Path.dirname(file_path), file_name)

    File.write!(full_path, data)
  end

  defp serialize(parent_account_id, transaction) do
    [_, date, opis_operacji, memo, payee, numer_konta, amount, _, _] = transaction

    %{
      date: date,
      opis_operacji: opis_operacji,
      memo: sanitize(memo),
      payee: sanitize(payee),
      numer_konta: sanitize(numer_konta),
      amount: format_number(amount)
    }
    |> prefill_fields()
    |> transform_operation(parent_account_id)
    |> Map.take([:date, :memo, :payee, :amount])
  end

  @internal_account_operations [
    "PRZELEW WŁASNY",
    "PRZELEW WEWNĘTRZNY PRZYCHODZĄCY",
    "PRZELEW REGULARNE OSZCZ",
    "PRZELEW NA TWOJE CELE"
  ]

  @interest_operations [
    "KAPITALIZACJA ODSETEK",
    "PODATEK OD ODSETEK KAPITAŁOWYCH"
  ]

  defp transform_operation(%{opis_operacji: opis_operacji} = transaction)
       when opis_operacji in @internal_account_operations do
    transform_internal(transaction, transaction.numer_konta)
  end

  defp transform_operation(%{opis_operacji: opis_operacji} = transaction)
       when opis_operacji in @interest_operations do
    Map.merge(transaction, %{payee: transaction.opis_operacji})
  end

  defp transform_operation(
         %{opis_operacji: "RĘCZNA SPŁATA KARTY KREDYT.", payee: card_id} = transaction
       ) do
    transform_internal(transaction, card_id)
  end

  defp transform_operation(%{opis_operacji: "ZAKUP PRZY UŻYCIU KARTY"} = transaction) do
    transaction
  end

  defp transform_operation(transaction), do: transaction

  defp transform_internal(transaction, account_id) do
    accounts()
    |> Enum.find(fn {_key, value} -> String.contains?(account_id, value.id) end)
    |> case do
      {_account, %{id: _, name: account_name}} ->
        Map.merge(transaction, %{payee: format_transfer(account_name)})

      _other ->
        IO.puts("Unknown account: #{account_id}")
        transaction
    end
  end

  defp prefill_fields(transaction) do
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
      %{numer_konta: ""} ->
        row

      %{numer_konta: numer_konta, memo: memo} ->
        Map.merge(row, %{memo: "#{memo} #{numer_konta}"})
    end
  end

  # Prepare an enum of accounts to be used for mapping.
  # The account name should be the same as in YNAB

  # defp accounts do
  #   %{
  #     ekonto: %{id: "", name: "Ekonto"}
  #   }
  # end

  defp accounts, do: %{}

  # Helpers

  # CSV file is Windows-encoded, conversion is needed to keep the special characters
  # Check if https://hexdocs.pm/codepagex/Codepagex.html#encoding_list/1 would work
  defp to_unicode(item) do
    :iconv.convert("CP1250", "UTF-8", item)
  end

  defp find_account_id(stream) do
    stream
    |> Enum.at(21)
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
MbankParser.process(System.argv())
# MbankParser.process(input_file_path)

# elixir mbank_parser.exs path/to/your/input.csv
