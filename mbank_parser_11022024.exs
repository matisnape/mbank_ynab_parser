defmodule MbankParserCLI do
  def main(argv) do
    {opts, _} = OptionParser.parse!(argv, switches: [input_file: :string, credit: :boolean, ignore_internal: :boolean])

    IO.inspect(opts)

    input_file = opts[:input_file] || raise ArgumentError, message: "Input file is required"
    ignore_internal = opts[:ignore_internal] || false

    case opts[:credit] do
      true ->
        IO.puts("Parsing credit card data:")
        mbank_parser = CreditCardParser.new(input_file)
      _ ->
        IO.puts("Parsing account data:")
        mbank_parser = AccountParser.new(input_file)
    end

    mbank_parser.convert_csv(input_file, ignore_internal)
  end
end

# Run the CLI with the command-line arguments
MbankParserCLI.main(System.argv())
