defmodule BankParser do
  @moduledoc """
  Main interface for the BankParser application.
  """

  @doc """
  Process a bank statement file.
  """
  def process(file_path) do
    BankParser.Parser.process(file_path)
  end
end
