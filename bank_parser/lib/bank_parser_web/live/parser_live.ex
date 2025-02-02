defmodule BankParserWeb.ParserLive do
  use Phoenix.LiveView

  alias BankParser.Actions.Parser

  def render(assigns) do
    ~H"""
    <div class="max-w-[95%] mx-auto p-6">
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
        <div class="mt-4">
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
                            <td
                              class="p-2 border-b text-xs font-mono truncate max-w-[200px]"
                              title={value}
                            >
                              {value}
                            </td>
                          <% end %>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>
            
    <!-- Parsed Data Column -->
            <div class={@show_original && "pl-6"}>
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
            </div>
          </div>
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
     |> assign(
       uploaded_files: [],
       result: nil,
       transactions: [],
       original_transactions: [],
       original_headers: nil,
       original_filename: nil,
       show_original: false
     )
     |> allow_upload(:csv, @upload_opts)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    # Store the original filename before processing
    filename = socket.assigns.uploads.csv.entries |> List.first() |> Map.get(:client_name)

    # Store in a new socket variable
    socket = assign(socket, original_filename: filename)

    socket
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

    tmp_path = Path.join(System.tmp_dir!(), filename)
    File.write!(tmp_path, csv_content)

    {:noreply,
     socket
     |> push_navigate(
       to: "/download/#{Path.basename(tmp_path)}",
       target: "_blank"
     )}
  end

  def handle_event("toggle_original", _params, socket) do
    {:noreply, assign(socket, show_original: !socket.assigns.show_original)}
  end

  defp upload_and_process_file(socket) do
    consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
      case Parser.process(path, &handle_transaction/2) do
        :ok -> {:ok, :ok}
        {:error, reason} -> {:ok, {:error, reason}}
      end
    end)
  end

  def handle_transaction({headers, original_rows, parsed}, pid) when is_pid(pid) do
    send(self(), {:transaction, {headers, original_rows, parsed}})
  end

  def handle_info({:transaction, {headers, original_rows, parsed}}, socket) do
    {:noreply,
     socket
     |> assign(:original_headers, headers)
     |> update(:original_transactions, fn transactions -> [original_rows | transactions] end)
     |> update(:transactions, fn transactions -> [parsed | transactions] end)}
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
