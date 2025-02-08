# csv_converter.exs

Mix.install(
  [
    {:csv, "~> 3.0"},
    {:iconv, "~> 1.0.10"}
  ],
  verbose: true
)

defmodule CsvConverter do
  def convert_to_utf8(input_file_path, output_file_path) do
    # Ensure the input file path is not empty
    if input_file_path == "" do
      IO.puts("Error: Input file path is empty.")
      System.halt(1)
    end

    # Read the file with the original encoding
    {:ok, content} = File.read(input_file_path)

    # Convert the content to UTF-8
    converted_content = :iconv.convert("CP1250", "UTF-8", content)
    # converted_content = :erlyconv.to_unicode(:cp1250, content)

    # Write the converted content to the output file
    File.write!(output_file_path, converted_content)
    IO.puts("Conversion successful. File saved as #{output_file_path}")
  end
end

# Run the conversion with the provided file path
input_file_path = System.argv() |> List.first()
output_file_path = Path.rootname(input_file_path) <> "_utf8.csv"

CsvConverter.convert_to_utf8(input_file_path, output_file_path)

# elixir csv_converter.exs path/to/your/input.csv
