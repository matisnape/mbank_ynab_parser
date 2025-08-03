defmodule BankParserWeb.Helpers do
  def no_reply(socket), do: {:noreply, socket}
  def ok(socket), do: {:ok, socket}
  def cont(socket), do: {:cont, socket}
end
