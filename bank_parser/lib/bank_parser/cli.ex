defmodule BankParser.CLI do
  @moduledoc """
  Command-line interface for the BankParser application
  """

  def main(args) do
    case args do
      [file_path] ->
        BankParser.Parser.process(file_path)

      _ ->
        IO.puts("Usage: bank_parser <path_to_csv_file>")
        System.halt(1)
    end
  end
end
