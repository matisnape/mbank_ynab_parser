defmodule BankParserWeb.ParserLive do
  use BankParserWeb, :live_view

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
        </button>
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

  @upload_opts [
    accept: ~w(.csv),
    max_entries: 1,
    # 10MB
    max_file_size: 10_000_000,
    auto_upload: true
  ]

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
      |> allow_upload(:csv, @upload_opts)

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

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    # Store the original filename before processing
    filename =
      socket.assigns.uploads.csv.entries
      |> List.first()
      |> Map.get(:client_name)

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
