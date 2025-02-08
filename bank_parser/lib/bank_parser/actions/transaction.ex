defmodule BankParser.Actions.Transaction do
  @moduledoc """
  Operations on transactions
  """
  import BankParser.Helpers, only: [accounts: 0, format_number: 1, sanitize: 1]

  def parse(:mbank, transaction) do
    case transaction do
      [_, data_operacji, opis_operacji, tytul, nadawca_odbiorca, numer_konta, kwota, saldo, _] ->
        %{
          date: data_operacji,
          operation: opis_operacji,
          memo: sanitize(tytul),
          payee: sanitize(nadawca_odbiorca),
          account_number: sanitize(numer_konta),
          amount: format_number(kwota),
          saldo: format_number(saldo)
        }

      [_, data_operacji, opis_operacji, tytul, _, nadawca_odbiorca, numer_konta, kwota, saldo, _] ->
        %{
          date: data_operacji,
          operation: opis_operacji,
          memo: sanitize(tytul),
          payee: sanitize(nadawca_odbiorca),
          account_number: sanitize(numer_konta),
          amount: format_number(kwota),
          saldo: format_number(saldo)
        }
    end
    |> prefill_ynab_fields()
    |> transform_operation()
    |> Map.take([:date, :memo, :payee, :amount, :saldo])
  end

  def parse(:ing, transaction) do
    [data_transakcji, _2, dane_kontrahenta, tytul, nr_rachunku, _6, szczegoly, _8, kwota, _9 | _] =
      transaction

    %{
      date: data_transakcji,
      operation: String.trim(szczegoly),
      memo: sanitize(tytul),
      payee: sanitize(dane_kontrahenta),
      account_number: sanitize(nr_rachunku),
      amount: format_number(kwota)
    }
    |> prefill_ynab_fields()
    |> transform_operation()
    |> Map.take([:date, :memo, :payee, :amount])
  end

  @internal_account_operations [
    "PRZELEW WŁASNY",
    "PRZELEW WEWNĘTRZNY PRZYCHODZĄCY",
    "PRZELEW REGULARNE OSZCZ",
    "WYPŁATA Z CELU"
  ]

  @interest_operations [
    "KAPITALIZACJA ODSETEK",
    "PODATEK OD ODSETEK KAPITAŁOWYCH"
  ]

  # @other_operations [
  #   "BLIK ZAKUP E-COMMERCE",
  #   "BLIK P2P-PRZYCHODZĄCY",
  #   "BLIK P2P-WYCHODZĄCY",
  #   "ZAKUP PRZY UŻYCIU KARTY"
  # ]

  defp transform_operation(
         %{operation: "PRZELEW", account_number: account_id, amount: amount} = transaction
       )
       when is_binary(account_id) do
    transform_ing(transaction, account_id, amount)
  end

  defp transform_operation(%{operation: opis_operacji} = transaction)
       when opis_operacji in @internal_account_operations do
    transform_internal(transaction, transaction.account_number, transaction.amount)
  end

  defp transform_operation(%{operation: opis_operacji} = transaction)
       when opis_operacji in @interest_operations do
    Map.merge(transaction, %{payee: transaction.operation})
  end

  defp transform_operation(%{operation: "PRZELEW NA TWOJE CELE"} = transaction) do
    transform_internal(transaction, transaction.operation, transaction.amount)
  end

  defp transform_operation(
         %{operation: "RĘCZNA SPŁATA KARTY KREDYT.", payee: card_id} = transaction
       ) do
    transform_internal(transaction, card_id, transaction.amount)
  end

  defp transform_operation(%{operation: "ZAKUP PRZY UŻYCIU KARTY"} = transaction) do
    transaction
  end

  defp transform_operation(%{account_number: ""} = transaction) do
    transaction
  end

  defp transform_operation(%{memo: memo, account_number: account_number} = transaction) do
    Map.merge(transaction, %{memo: memo <> " " <> account_number})
  end

  defp transform_internal(transaction, account_id, amount) do
    accounts()
    |> Enum.find(fn account ->
      String.contains?(account_id, account.id) or
        (transaction.operation == "PRZELEW NA TWOJE CELE" and
           account.id == "PRZELEW NA TWOJE CELE")
    end)
    |> case do
      %{id: _, name: account_name} ->
        Map.merge(transaction, %{payee: format_transfer(account_name, amount)})

      _other ->
        IO.inspect(["Unknown account: #{account_id} for transaction", transaction])
        transaction
    end
  end

  defp transform_ing(transaction, account_id, amount) do
    accounts()
    |> Enum.find(&String.contains?(account_id, &1.id))
    |> case do
      %{id: _, name: account_name} ->
        Map.merge(transaction, %{payee: format_transfer(account_name, amount)})

      _other ->
        transaction
    end
  end

  defp prefill_ynab_fields(transaction) do
    transaction
    |> populate_payee_if_empty()
    |> merge_accountid_with_memo()
  end

  defp populate_payee_if_empty(row) do
    case row do
      %{payee: "", memo: memo} -> Map.merge(row, %{payee: memo, memo: ""})
      _ -> row
    end
  end

  defp merge_accountid_with_memo(row) do
    case row do
      %{account_number: ""} ->
        row

      %{account_number: numer_konta, memo: memo} ->
        Map.merge(row, %{memo: "#{memo} #{numer_konta}"})
    end
  end

  defp format_transfer(account_name, "-" <> _rest), do: "Transfer: " <> account_name
  defp format_transfer(account_name, _amount), do: "Transfer from: " <> account_name
end
