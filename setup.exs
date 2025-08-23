Mix.install(
  [
    {:jason, "~> 1.4"}
  ],
  verbose: true
)

defmodule BankParserSetup do
  @moduledoc """
  Interactive setup wizard for BankParser configuration
  """

  def run do
    IO.puts("\n🏦 Welcome to Bank Parser Setup Wizard")
    IO.puts("=====================================\n")

    if File.exists?("config.json") do
      IO.puts("⚠️  config.json already exists.")
      overwrite = 
        case IO.gets("Do you want to overwrite it? (y/N): ") do
          :eof -> "n"
          input -> input |> String.trim() |> String.downcase()
        end
      
      unless overwrite == "y" or overwrite == "yes" do
        IO.puts("Setup cancelled.")
        System.halt(0)
      end
    end

    config = %{
      "accounts" => collect_accounts(),
      "settings" => collect_settings()
    }

    save_config(config)
    IO.puts("\n✅ Configuration saved to config.json")
    IO.puts("🚀 You can now run: elixir bank_parser.exs your_file.csv")
  end

  defp collect_accounts do
    IO.puts("Let's configure your bank accounts for YNAB mapping.\n")
    IO.puts("💡 You'll need the account identifiers from your CSV files.")
    IO.puts("   For internal transfers, these help map 'Transfer: Account Name' in YNAB.\n")
    
    collect_accounts_loop([])
  end

  defp collect_accounts_loop(accounts) do
    IO.puts("Account #{length(accounts) + 1}:")
    
    name = 
      case IO.gets("  YNAB Account Name (e.g., 'Mbank Ekonto PLN'): ") do
        :eof -> ""
        input -> String.trim(input)
      end
    
    if name == "" do
      if Enum.empty?(accounts) do
        IO.puts("❌ You need at least one account!")
        collect_accounts_loop(accounts)
      else
        accounts
      end
    else
      IO.puts("  💡 Account ID/identifier from CSV (leave empty if unsure):")
      IO.puts("     - For mBank: account number or partial number")
      IO.puts("     - For special accounts: 'PRZELEW NA TWOJE CELE' for savings goals")
      
      id = 
        case IO.gets("  Account ID: ") do
          :eof -> ""
          input -> String.trim(input)
        end

      description = 
        case IO.gets("  Description (optional): ") do
          :eof -> ""
          input -> String.trim(input)
        end

      account = %{
        "id" => id,
        "name" => name,
        "description" => if(description == "", do: nil, else: description)
      }

      new_accounts = accounts ++ [account]
      
      IO.puts("\n📝 Current accounts:")
      new_accounts
      |> Enum.with_index(1)
      |> Enum.each(fn {acc, idx} ->
        desc = if acc["description"], do: " (#{acc["description"]})", else: ""
        IO.puts("   #{idx}. #{acc["name"]}#{desc}")
      end)

      continue = 
        case IO.gets("\nAdd another account? (y/N): ") do
          :eof -> "n"
          input -> input |> String.trim() |> String.downcase()
        end
      
      if continue == "y" or continue == "yes" do
        IO.puts("")
        collect_accounts_loop(new_accounts)
      else
        new_accounts
      end
    end
  end

  defp collect_settings do
    IO.puts("\n⚙️  Settings Configuration:")
    
    prefix = 
      case IO.gets("Output filename prefix (default: 'eYNAB_ready_'): ") do
        :eof -> "eYNAB_ready_"
        "" -> "eYNAB_ready_"
        input -> String.trim(input)
      end

    include_balance = 
      case IO.gets("Include balance column for mBank files? (Y/n): ") do
        :eof -> true
        input -> 
          input
          |> String.trim()
          |> String.downcase()
          |> case do
            "n" -> false
            "no" -> false
            _ -> true
          end
      end

    %{
      "output_prefix" => prefix,
      "include_balance" => include_balance,
      "date_format" => "YYYY-MM-DD"
    }
  end

  defp save_config(config) do
    json = Jason.encode!(config, pretty: true)
    File.write!("config.json", json)
  end
end

# Run the setup wizard
BankParserSetup.run()