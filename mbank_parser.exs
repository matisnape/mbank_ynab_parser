Mix.install(
  [
    {:csv, "~> 3.0"},
    {:erlyconv, github: "eugenehr/erlyconv"}
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
    file_path
    |> File.stream!()
    |> drop_metadata()
    |> CSV.decode!(separator: ?;, field_transform: &to_unicode/1)
    |> Stream.map(&serialize(&1))
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

  defp serialize([_, date, opis_operacji, memo, payee, numer_konta, amount, _, _]) do
    %{
      date: date,
      opis_operacji: opis_operacji,
      memo: sanitize(memo),
      payee: sanitize(payee),
      numer_konta: sanitize(numer_konta),
      amount: format_amount(amount)
    }
    |> initial_transformation()
    |> transform_operation()
    |> Map.take([:date, :memo, :payee, :amount])
  end

  defp transform_operation(
         %{opis_operacji: "PRZELEW WŁASNY", numer_konta: account_id} = transaction
       ) do
    transform_internal(transaction, account_id)
  end

  defp transform_operation(
         %{opis_operacji: "PRZELEW WEWNĘTRZNY PRZYCHODZĄCY", numer_konta: account_id} =
           transaction
       ) do
    transform_internal(transaction, account_id)
  end

  defp transform_operation(
         %{opis_operacji: "PRZELEW REGULARNE OSZCZ", numer_konta: account_id} = transaction
       ) do
    transform_internal(transaction, account_id)
  end

  defp transform_operation(%{opis_operacji: "PRZELEW NA TWOJE CELE"} = transaction) do
    transform_internal(transaction, transaction.opis_operacji)
  end

  defp transform_operation(
         %{opis_operacji: "RĘCZNA SPŁATA KARTY KREDYT.", payee: card_id} = transaction
       ) do
    transform_internal(transaction, card_id)
  end

  defp transform_operation(%{opis_operacji: "ZAKUP PRZY UŻYCIU KARTY"} = transaction) do
    transaction
  end

  defp transform_operation(%{opis_operacji: "KAPITALIZACJA ODSETEK"} = transaction) do
    Map.merge(transaction, %{payee: transaction.opis_operacji})
  end

  defp transform_operation(%{opis_operacji: "PODATEK OD ODSETEK KAPITAŁOWYCH"} = transaction) do
    Map.merge(transaction, %{payee: transaction.opis_operacji})
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

  defp initial_transformation(transaction) do
    transaction
    |> populate_payee_if_empty()
    |> merge_accountid_with_memo()
  end

  defp populate_payee_if_empty(%{payee: "", memo: memo} = row) do
    Map.merge(row, %{payee: memo, memo: ""})
  end

  defp populate_payee_if_empty(row), do: row

  defp merge_accountid_with_memo(%{numer_konta: ""} = row), do: row

  defp merge_accountid_with_memo(%{numer_konta: numer_konta, memo: memo} = row) do
    Map.merge(row, %{memo: "#{memo} #{numer_konta}"})
  end

  # Prepare an enum of accounts to be used for mapping

  # defp accounts do
  #   %{
  #     ekonto: %{id: "", name: "Ekonto"}
  #   }
  # end

  defp accounts, do: %{}

  # Helpers

  defp to_unicode(item) do
    :erlyconv.to_unicode(:cp1250, item)
  end

  defp drop_metadata(stream) do
    stream
    |> Stream.drop(38)
    |> Stream.drop(-5)
  end

  defp format_amount(amount) do
    amount
    |> String.replace(",", ".")
    |> String.replace(" ", "")
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
