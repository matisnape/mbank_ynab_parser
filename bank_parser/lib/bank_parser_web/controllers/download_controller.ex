defmodule BankParserWeb.DownloadController do
  use BankParserWeb, :controller

  def download(conn, %{"filename" => filename}) do
    path = Path.join(System.tmp_dir!(), filename)

    # example path: /var/folders/qm/smth/T/eYNAB_ready_250113_250201.csv"

    conn
    |> send_download({:file, path},
      filename: filename,
      content_type: "text/csv",
      disposition: :attachment
    )
    |> then(fn conn ->
      File.rm!(path)
      conn
    end)
  end
end
