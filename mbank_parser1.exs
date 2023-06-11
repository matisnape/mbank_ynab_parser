defmodule MbankParser do
  def main(args) do
    case args do
      [filename] ->
        case File.read(filename) do
          {:ok, contents} ->
            case CSV.decode(contents) do
              {:ok, rows} ->
                duplicated_rows = rows ++ rows

                output_filename =
                  File.dirname(filename) <> "/YNAB_ready_" <> File.basename(filename)

                case File.write(output_filename, CSV.encode(duplicated_rows)) do
                  :ok ->
                    IO.puts("File saved to #{output_filename}")

                  {:error, reason} ->
                    IO.puts("Error saving file: #{reason}")
                end

              {:error, reason} ->
                IO.puts("Error decoding CSV file: #{reason}")
            end

          {:error, reason} ->
            IO.puts("Error reading file: #{reason}")
        end

      _ ->
        IO.puts("Usage: elixir mbank_parser.exs [filename]")
    end
  end
end

if System.find_executable("mix") == :ok do
  Mix.install(["csv"])
end

MbankParser.main(System.argv())
