defmodule BankParser.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BankParserWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:bank_parser, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BankParser.PubSub},
      # Start a worker by calling: BankParser.Worker.start_link(arg)
      # {BankParser.Worker, arg},
      # Start to serve requests, typically the last entry
      BankParserWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BankParser.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BankParserWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
