defmodule Fitzyo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Fitzyo.Workflow.SuspendedReactors.init()

    children = [
      FitzyoWeb.Telemetry,
      Fitzyo.Repo,
      Fitzyo.Workflow.NodeRegistry,
      {DNSCluster, query: Application.get_env(:fitzyo, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:fitzyo, :ash_domains),
         Application.fetch_env!(:fitzyo, Oban)
       )},
      {Phoenix.PubSub, name: Fitzyo.PubSub},
      # Start a worker by calling: Fitzyo.Worker.start_link(arg)
      # {Fitzyo.Worker, arg},
      # Start to serve requests, typically the last entry
      FitzyoWeb.Endpoint,
      {Absinthe.Subscription, FitzyoWeb.Endpoint},
      AshGraphql.Subscription.Batcher
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fitzyo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FitzyoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
