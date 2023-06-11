Mix.install(
  [
    {:csv, "~> 3.0"},
    {:erlyconv, github: "eugenehr/erlyconv"}
  ],
  config: [],
  # force: true,
  verbose: true
)

defmodule MbankParser do
  @moduledoc """
  Parses an mbank CSV file and saves a processed version of the file in UTF-8 format.

  ## Examples

      iex> MbankParser.parse("example.csv")

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

  @ynab_headers ~w(DATE MEMO PAYEE AMOUNT)
  @ynab_delimiter ","
  @ynab_filename_prefix "YNAB_ready_"

  # def process(file_path) do
  #   file_path
  #   |> File.read([:line, :raw, :utf8], :utf8)
  #   |> String.split("\n") |> Enum.drop(38) |> Enum.drop_last(5)
  #   output_file_name = "YNAB_ready_#{File.basename(file_path)}"
  #   CSV.write(output_file_name, [%{@headers}], write_headers: true, encoding: "utf-8")
  #   CSV.append(output_file_name, lines, write_headers: false, encoding: "utf-8")
  # end

  def parse(file_path) do
    file_path
    |> File.stream!()
    |> drop_metadata()
    |> Stream.each(fn item ->
      # Why there's a bitstring and not a string
      :erlyconv.to_unicode(:cp1250, item)
      |> IO.inspect()
      |> prepare()
    end)
    # |> CSV.encode(headers: @ynab_headers, separators: [",", ";"])
    |> Enum.to_list()

    # |> IO.inspect(label: "dropped")
    # |> CSV.decode(headers: false, separators: [",", ";"])
    # |> IO.inspect(label: "decoded")
    # |> CSV.encode(headers: ["DATE", "MEMO", "PAYEE", "AMOUNT"], separators: [",", ";"])
    # |> IO.inspect(label: "encoded")
    # |> write_file(file_path)
  end

  defp write_file(data, file_path) do
    file_name = "YNAB_ready_" <> Path.basename(file_path)
    full_path = Path.join(Path.dirname(file_path), file_name)
    File.write!(full_path, data, [:utf8])
  end

  # def parse2(file_path) do
  #   # input_file = File.read!(file_path, [:read, :binary], :utf8, :cp1250)

  #   file_path
  #   # Read the input file with cp1250 encoding
  #   |> File.read!([:read, :binary], :utf8, :cp1250)
  #   # Split the input file into lines and remove the first 38 and last 5 lines
  #   |> drop_metadata()
  #   # Join the processed lines with a newline character
  #   |> Enum.join("\n")
  #   |> IO.inspect()

  #   # # Create the output file name with the YNAB_ready_ prefix
  #   # output_file_name = "YNAB_ready_" <> File.basename(file_path)

  #   # # Write the output file to the same location as the input file with UTF-8 encoding
  #   # File.write!(
  #   #   File.dirname(file_path) <> "/" <> output_file_name,
  #   #   output_file,
  #   #   [:write, :binary],
  #   #   :utf8
  #   # )
  # end

  defp prepare(row) do
    [_, date, opis_operacji, memo, payee, numer_konta, amount, _, _] = String.split(row, ";")

    %{date: date, memo: memo, payee: payee, amount: amount} =
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

    [date, memo, payee, amount]
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
    |> Enum.find(fn {key, value} -> String.contains?(account_id, value.id) end)
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

  defp accounts do
    %{
      ekonto: %{id: "", name: "Ekonto"}
    }
  end

  # Helpers

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
MbankParser.parse(System.argv())
