defmodule BankParser.Actions.Parser do
  @moduledoc """
  Parses bank CSV files (mBank and ING) and saves a processed version of the file
  """

  alias BankParser.Actions.Transaction

  @ynab_headers ~w(date payee memo amount saldo)a
  @ynab_filename_prefix "eYNAB_ready_"

  def process(file_path, callback \\ fn _, _ -> :ok end) do
    file = File.stream!(file_path)
    bank_type = detect_bank_type(file)

    file
    |> drop_metadata(bank_type)
    |> prepare_data(bank_type, callback)

    IO.puts("Parsing complete for #{bank_type} file")
  end

  def process_and_save(file_path) do
    file_path
    |> process()
    |> save_to_file(file_path)
  end

  def save_to_file(data, file_path) do
    file_name = @ynab_filename_prefix <> Path.basename(file_path)
    full_path = Path.join(Path.dirname(file_path), file_name)

    File.write!(full_path, data)
    IO.puts("File saved as #{file_name}")
  end

  def ynab_headers, do: @ynab_headers

  def generate_output_filename(nil), do: "#{@ynab_filename_prefix}_transactions.csv"

  def generate_output_filename(original_filename) do
    @ynab_filename_prefix <> original_filename
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

  defp prepare_data(stream, bank_type, callback) do
    decoded_stream =
      CSV.decode!(stream, separator: ?;, field_transform: &to_unicode/1, escape_character: 0)

    [headers | data] = Enum.to_list(decoded_stream)

    data
    |> Stream.map(fn transaction ->
      parsed = Transaction.parse(bank_type, transaction)
      callback.({headers, transaction, parsed}, self())
      parsed
    end)
    |> CSV.encode(
      headers: @ynab_headers,
      separator: ?,,
      delimeter: "\r\n"
    )
    |> Enum.to_list()
  end

  # FILES Utils

  defp drop_metadata(stream, :mbank) do
    stream
    |> Stream.drop(37)
    |> Stream.drop(-5)
  end

  defp drop_metadata(stream, :ing) do
    stream
    |> Stream.drop(19)
    |> Stream.drop(-3)
  end

  defp to_unicode(row) do
    :iconv.convert("CP1250", "UTF-8", row)
  end
end
