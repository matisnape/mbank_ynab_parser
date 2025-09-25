defmodule BankParserWeb.ParserLive do
  use BankParserWeb, :live_view

  alias BankParser.Actions.Parser

  def mount(params, _session, socket) do
    socket
    |> set_default_assigns()
    |> assign(original_filename: nil)
    |> allow_upload(:csv, upload_opts())
    |> maybe_load_test_file(params)
    |> ok()
  end

  def handle_progress(:csv, entry, socket) do
    if entry.done? do
      # Reset state when a new file is actually uploaded and ready for processing
      socket
      |> set_default_assigns()
      |> assign(original_filename: entry.client_name)
      |> process_finished_upload()
    else
      socket
      |> no_reply()
    end
  end

  def handle_event("validate", _params, socket) do
    socket
    |> no_reply()
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

    # Clear upload entries after saving
    socket =
      socket.assigns.uploads.csv.entries
      |> Enum.reduce(socket, fn entry, acc_socket ->
        cancel_upload(acc_socket, :csv, entry.ref)
      end)

    socket
    |> push_navigate(
      to: "/download/#{Path.basename(tmp_path)}",
      target: "_blank"
    )
    |> no_reply()
    |> IO.inspect(label: "CSV saved", limit: :infinity)
  end

  def handle_event("toggle_original", _params, socket) do
    socket
    |> assign(show_original: !socket.assigns.show_original)
    |> no_reply()
  end

  def handle_transaction({headers, original_rows, parsed}, pid) when is_pid(pid) do
    # Get the LiveView process ID from the current process dictionary
    lv_pid = Process.get(:live_view_pid) || pid
    send(lv_pid, {:transaction, {headers, original_rows, parsed}})
  end

  def handle_info({:transaction, {headers, original_rows, parsed}}, socket) do
    socket
    |> assign(:original_headers, headers)
    |> update(:original_transactions, fn transactions -> [original_rows | transactions] end)
    |> update(:transactions, fn transactions -> [parsed | transactions] end)
    |> no_reply()
  end

  def handle_info(:clear_flash, socket) do
    socket
    |> assign(result: nil)
    |> no_reply()
  end

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
              {error_msg(err)}
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

  defp process_finished_upload(socket) do
    Process.put(:live_view_pid, self())

    result =
      socket
      |> consume_uploaded_entries(:csv, fn %{path: path}, _entry ->
        case Parser.process(path, &handle_transaction/2) do
          :ok -> {:ok, :uploaded}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    case result do
      [:uploaded] ->
        Process.send_after(self(), :clear_flash, 5_000)

        socket
        |> assign(result: "File processed successfully")
        |> no_reply()

      [{:error, reason}] ->
        socket
        |> put_flash(:error, reason)
        |> no_reply()

      _other ->
        socket
        |> put_flash(:error, "Unexpected upload result")
        |> no_reply()
    end
  end

  defp set_default_assigns(socket) do
    socket
    |> assign(
      result: nil,
      transactions: [],
      original_transactions: [],
      original_headers: nil,
      show_original: false
    )
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

  # Attempts to load a test file if specified in params
  # Returns socket with appropriate assignments based on the result
  defp maybe_load_test_file(socket, params) do
    case Map.get(params, "load_test_file") do
      nil ->
        socket

      test_file when is_binary(test_file) ->
        load_test_file(socket, test_file)

      _ ->
        assign(socket, result: "Invalid test file parameter")
    end
  end

  # Loads the specified test file and processes it
  defp load_test_file(socket, test_file) do
    file_path = build_test_file_path(test_file)

    if File.exists?(file_path) do
      case Parser.process(file_path, &handle_transaction/2) do
        :ok ->
          assign(socket, original_filename: Path.basename(test_file))

        {:error, reason} ->
          assign(socket, result: "Error processing test file: #{reason}")
      end
    else
      assign(socket, result: "Test file not found: #{test_file}")
    end
  end

  # Builds the full path to a test file
  defp build_test_file_path(filename) do
    Application.app_dir(:bank_parser, "priv/test_files/#{filename}")
  end

  defp error_msg(error) when is_atom(error) do
    case error do
      :too_large -> "File is too large"
      :too_many_files -> "Too many files"
      :not_accepted -> "You can only upload CSV files"
      _ -> "Unknown error: #{error}"
    end
  end
end
