defmodule BankParserWeb.Components.Table do
  use Phoenix.Component
  use Gettext, backend: BankParserWeb.Gettext

  attr :transactions, :list, required: true

  def parsed_data_table(assigns) do
    ~H"""
    <h2 class="text-xl font-semibold mb-3">Parsed Data</h2>
    <div class="overflow-x-auto">
      <table class="min-w-full table-auto border-collapse text-sm">
        <thead>
          <tr class="bg-gray-100 h-[65px]">
            <th class="text-left p-2 border-b">Date</th>
            <th class="text-left p-2 border-b">Payee</th>
            <th class="text-left p-2 border-b">Memo</th>
            <th class="text-right p-2 border-b">Amount</th>
            <th class="text-right p-2 border-b">Balance</th>
          </tr>
        </thead>
        <tbody>
          <%= for transaction <- @transactions do %>
            <tr class="hover:bg-gray-50 h-[42px]">
              <td class="p-2 border-b">{transaction.date}</td>
              <td class="p-2 border-b truncate max-w-[200px]" title={transaction.payee}>
                {transaction.payee}
              </td>
              <td class="p-2 border-b truncate max-w-[200px]" title={transaction.memo}>
                {transaction.memo}
              </td>
              <td class="p-2 border-b text-right">{transaction.amount}</td>
              <td class="p-2 border-b text-right">{transaction.saldo}</td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :original_transactions, :list, required: true
  attr :original_headers, :list

  def original_data_table(assigns) do
    ~H"""
    <div class="bg-gray-100/50 pr-6">
      <h2 class="text-xl font-semibold mb-3">Original Data</h2>
      <div class="overflow-x-auto">
        <table class="min-w-full table-auto border-collapse text-sm">
          <thead>
            <tr class="bg-gray-100 h-[65px]">
              <%= for header <- @original_headers || [] do %>
                <th class="text-left p-2 border-b text-xs">{header}</th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for transaction <- @original_transactions do %>
              <tr class="hover:bg-gray-100/50 h-[42px]">
                <%= for value <- transaction do %>
                  <td class="p-2 border-b text-xs font-mono truncate max-w-[200px]" title={value}>
                    {value}
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :transactions, :list, required: true
  attr :original_transactions, :list, required: true
  attr :original_headers, :list
  attr :original_filename, :string, required: true
  attr :show_original, :boolean, default: false

  def transactions_table(assigns) do
    ~H"""
    <%= if @transactions != [] do %>
      <div id="single_file_transactions" class="mt-4">
        <div class="flex justify-end mb-4 items-center gap-4">
          <div class="text-gray-600">
            <span class="font-medium"><b>Original file:</b></span> {@original_filename}
          </div>
          <label class="flex items-center gap-2">
            <input
              type="checkbox"
              phx-click="toggle_original"
              checked={@show_original}
              class="rounded border-gray-300"
            />
            <span class="text-sm">Show original data</span>
          </label>
          <div>
            <button
              phx-click="save_csv"
              class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"
            >
              Save to CSV
            </button>
          </div>
        </div>

        <div class={[
          "grid grid-cols-1 gap-6 divide-x divide-gray-200",
          @show_original && "md:grid-cols-2"
        ]}>
          <%= if @show_original do %>
            <!-- Original Data Column -->
            <.original_data_table
              original_transactions={@original_transactions}
              original_headers={@original_headers}
            />
          <% end %>

          <div class={@show_original && "pl-6"}>
            <.parsed_data_table transactions={@transactions} />
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
