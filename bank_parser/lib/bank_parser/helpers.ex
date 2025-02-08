defmodule BankParser.Helpers do
  # Prepare an enum of accounts to be used for mapping.
  # The account name should be the same as in YNAB

  # Take a look at priv/accounts/accounts.example.json

  def accounts() do
    accounts_path()
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(fn account ->
      account
      |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)
      |> BankParser.Models.Account.new()
    end)
  end

  def format_number(number) do
    number
    |> String.replace(",", ".")
    |> String.replace(" ", "")
    |> String.trim()
  end

  def sanitize(string) do
    boring_strings = [
      "'",
      "\""
    ]

    string
    |> String.replace(boring_strings, "")
    |> String.split()
    |> Enum.join(" ")
  end

  defp accounts_path() do
    Application.app_dir(:bank_parser, "priv/accounts/accounts.json")
  end
end
