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
  @doc """
  Parses an mbank CSV file and saves a processed version of the file in UTF-8 format.

  ## Examples

      iex> MbankParser.parse("example.csv")

  """
  @ynab_headers ~w(DATE MEMO PAYEE AMOUNT)
  @ynab_delimiter ","
  @ynab_filename_prefix "YNAB_ready_"
  @owner "ANNA MARIA NOWAK"
  @date_col 0
  @opis_operacji_col 1
  @memo_col 2
  @payee_col 3
  @numer_konta_col 4
  @amount_col 5

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
      |> transform()

      # |> IO.write()
    end)
    |> Enum.to_list()

    # |> IO.inspect(label: "dropped")
    # |> CSV.decode(headers: false, separators: [",", ";"])
    # |> IO.inspect(label: "decoded")
    # |> CSV.encode(headers: ["DATE", "MEMO", "PAYEE", "AMOUNT"], separators: [",", ";"])
    # |> IO.inspect(label: "encoded")
    # |> write_file(file_path)
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

  defp drop_metadata(stream) do
    stream
    |> Stream.drop(38)
    |> Stream.drop(-5)
  end

  def transform(row) do
    [_, date, opis_operacji, memo, payee, numer_konta, amount, _, _] = String.split(row, ";")

    %{
      date: date,
      opis_operacji: opis_operacji,
      memo: memo,
      payee: payee,
      numer_konta: numer_konta,
      amount: format_amount(amount)
    }
    |> populate_payee_if_empty
    |> merge_accountid_with_memo

    # |> [date, opis_operacji, memo, payee, numer_konta, format_amount(amount)]
    |> IO.inspect(label: "newrow")
  end

  defp populate_payee_if_empty(%{payee: "  ", memo: memo} = row) do
    Map.merge(row, %{payee: memo, memo: ""})
  end

  defp populate_payee_if_empty(row), do: row

  defp format_amount(amount) do
    amount
    |> String.replace(",", ".")
    |> String.replace(" ", "")
  end

  defp merge_accountid_with_memo(%{numer_konta: ""} = row), do: row

  defp merge_accountid_with_memo(%{numer_konta: numer_konta, memo: memo} = row) do
    Map.merge(row, %{memo: memo <> numer_konta})
  end

  defp rename_internal_transfer(%{opis_operacji: opis_operacji, numer_konta: numer_konta} = row) do
  end

  def write_file(data, file_path) do
    file_name = "YNAB_ready_" <> Path.basename(file_path)
    full_path = Path.join(Path.dirname(file_path), file_name)
    File.write!(full_path, data, [:utf8])
  end

  defp operations do
    %{
      regularne: "PRZELEW REGULARNE OSZCZ",
      splata_kart: "RĘCZNA SPŁATA KARTY KREDYT.",
      kapitalizacja: "KAPITALIZACJA ODSETEK",
      podatek_odsetki: "PODATEK OD ODSETEK",
      internal_transfer: "PRZELEW WŁASNY",
      internal_incoming: "PRZELEW WEWNĘTRZNY PRZYCHODZĄCY"
    }
  end
end

# Call the function with the provided file path
MbankParser.parse(System.argv())
