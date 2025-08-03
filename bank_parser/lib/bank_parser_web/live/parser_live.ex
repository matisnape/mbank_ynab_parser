defmodule BankParserWeb.ParserLive do
  use BankParserWeb, :live_view

  alias BankParser.Actions.Parser

  def render(assigns) do
    ~H"""
    <div class="max-w-[95%] mx-auto p-6">
      <h1 class="text-2xl font-bold mb-4">Bank Statement Parser</h1>

      <form phx-change="validate" phx-drop-target={@uploads.csv.ref}>
        <div class="mb-4">
          <div class="flex items-center justify-center w-full">
            <label
              for={@uploads.csv.ref}
              class="flex flex-col items-center justify-center w-full h-50 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100"
              phx-drop-target={@uploads.csv.ref}
            >
              <div class="flex flex-col items-center justify-center pt-5 pb-6">
                <svg
                  class="w-8 h-8 mb-4 text-gray-500"
                  aria-hidden="true"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 20 16"
                >
                  <path
                    stroke="currentColor"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"
                  />
                </svg>
                <p class="mb-2 text-lg text-gray-500">
                  <span class="font-semibold">Click to upload</span> or drag and drop
                </p>
                <p class="text-xs text-gray-500">CSV files only</p>

                <%= for entry <- @uploads.csv.entries do %>
                  <div class="text-sm text-gray-500">
                    {entry.client_name} - {entry.progress}%
                  </div>
                <% end %>
              </div>
              <.live_file_input upload={@uploads.csv} class="hidden" />
            </label>
          </div>

          <%= for err <- upload_errors(@uploads.csv) do %>
            <div class="mt-2 text-sm text-red-500">
              {error_to_string(err)}
            </div>
          <% end %>
        </div>
      </form>

      <div :if={@result} class="mt-4 p-4 bg-green-100 rounded">
        {@result}
      </div>

      <.transactions_table
        transactions={@transactions}
        original_transactions={@original_transactions}
        original_headers={@original_headers}
        original_filename={@original_filename}
        show_original={@show_original}
      />
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket =
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
      |> allow_upload(:csv, upload_opts())

    # Load test file if provided
    if test_file = Map.get(params, "load_test_file") do
      file_path = Application.app_dir(:bank_parser, "priv/test_files/#{test_file}")

      if File.exists?(file_path) do
        Parser.process(file_path, &handle_transaction/2)
        {:ok, assign(socket, original_filename: Path.basename(test_file))}
      else
        {:ok, assign(socket, result: "Test file not found: #{test_file}")}
      end
    else
      {:ok, socket}
    end
  end

  def handle_progress(:csv, entry, socket) do
    if entry.done? do
      # Store the LiveView PID in the process dictionary
      Process.put(:live_view_pid, self()) |> IO.inspect(label: "live_view_pid")

      filename =
        socket.assigns.uploads.csv.entries
        |> List.first()
        |> Map.get(:client_name)

      # First assign the filename
      socket = assign(socket, original_filename: filename)

      socket
      |> IO.inspect(label: "socket")
      |> upload_and_process_file()
      |> IO.inspect(label: "upload_and_process_file")
      |> handle_result(socket)
      |> IO.inspect(label: "handle_result", limit: :infinity)
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
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

  def handle_transaction({headers, original_rows, parsed}, pid) when is_pid(pid) do
    # Get the LiveView process ID from the current process dictionary
    lv_pid = Process.get(:live_view_pid) || pid |> IO.inspect(label: "anks pid")
    send(lv_pid, {:transaction, {headers, original_rows, parsed}})
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

  defp upload_and_process_file(socket) do
    # Then consume the uploaded entries
    result =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        case Parser.process(path, &handle_transaction/2) do
          :ok -> {:ok, :ok}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    # Return both the result and the updated socket with filename
    result
  end

  defp upload_opts do
    [
      accept: ~w(.csv),
      max_entries: 1,
      # 10MB
      max_file_size: 10_000_000,
      auto_upload: true,
      progress: &handle_progress/3
    ]
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "You can only upload CSV files"
end
