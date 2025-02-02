defmodule BankParserWeb.ParserLive do
  use Phoenix.LiveView

  alias BankParser.Actions.Parser

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-4">Bank Statement Parser</h1>

      <form phx-submit="save" phx-change="validate">
        <div class="mb-4">
          <.live_file_input upload={@uploads.csv} class="block w-full" />
        </div>

        <button type="submit" class="bg-blue-500 text-white px-4 py-2 rounded">
          Upload and Process
        </button>
      </form>

      <div :if={@result} class="mt-4 p-4 bg-green-100 rounded">
        {@result}
      </div>

      <%= if @transactions != [] do %>
        <div :if={@transactions != []} class="mt-4 overflow-x-auto">
          <div class="flex justify-end mb-4">
            <button
              phx-click="save_csv"
              class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"
            >
              Save to CSV
            </button>
          </div>
          <table class="min-w-full table-auto border-collapse">
            <thead>
              <tr class="bg-gray-100">
                <th class="text-left p-3 border-b">Date</th>
                <th class="text-left p-3 border-b w-1/3">Payee</th>
                <th class="text-left p-3 border-b w-1/3">Memo</th>
                <th class="text-right p-3 border-b">Amount</th>
                <th class="text-right p-3 border-b">Balance</th>
              </tr>
            </thead>
            <tbody>
              <%= for transaction <- @transactions do %>
                <tr class="hover:bg-gray-50">
                  <td class="p-3 border-b">{transaction.date}</td>
                  <td class="p-3 border-b">{transaction.payee}</td>
                  <td class="p-3 border-b">{transaction.memo}</td>
                  <td class="p-3 border-b text-right">{transaction.amount}</td>
                  <td class="p-3 border-b text-right">{transaction.saldo}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  @upload_opts [
    accept: ~w(.csv),
    max_entries: 1,
    # 10MB
    max_file_size: 10_000_000,
    auto_upload: true
  ]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(uploaded_files: [], result: nil, transactions: [], original_filename: nil)
     |> allow_upload(:csv, @upload_opts)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    # Store the original filename before processing
    filename = socket.assigns.uploads.csv.entries |> List.first() |> Map.get(:client_name)

    socket
    |> assign(original_filename: filename)
    |> upload_and_process_file()
    |> handle_result(socket)
  end

  def handle_event("save_csv", _params, socket) do
    csv_content =
      socket.assigns.transactions
      |> Enum.reverse()
      |> CSV.encode(headers: Parser.ynab_headers(), separator: ?,, delimiter: "\r\n")
      |> Enum.to_list()
      |> Enum.join()

    filename = Parser.generate_output_filename(socket.assigns.original_filename)

    {:noreply,
     socket
     |> put_flash(:info, "Downloading CSV file")
     |> push_event("download", %{
       filename: filename,
       content: csv_content,
       type: "text/csv"
     })}
  end

  defp upload_and_process_file(socket) do
    consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
      case Parser.process(path, &handle_transaction/2) do
        :ok -> {:ok, :ok}
        {:error, reason} -> {:ok, {:error, reason}}
      end
    end)
  end

  def handle_transaction(transaction, socket) do
    send(self(), {:transaction, transaction})
    socket
  end

  def handle_info({:transaction, transaction}, socket) do
    {:noreply, update(socket, :transactions, fn transactions -> [transaction | transactions] end)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, assign(socket, result: nil)}
  end

  defp handle_result([{:error, reason}], socket) do
    {:noreply, put_flash(socket, :error, reason)}
  end

  defp handle_result([:ok], socket) do
    Process.send_after(self(), :clear_flash, 5_000)
    {:noreply, assign(socket, result: "File processed successfully")}
  end
end
