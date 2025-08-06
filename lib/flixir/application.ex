defmodule Flixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlixirWeb.Telemetry,
      Flixir.Repo,
      {DNSCluster, query: Application.get_env(:flixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Flixir.PubSub},
      # Start the search cache
      {Flixir.Media.Cache, Application.get_env(:flixir, :search_cache, [])},
      # Start the reviews cache
      {Flixir.Reviews.Cache, Application.get_env(:flixir, :reviews_cache, [])},
      # Start the session cleanup background job
      {Flixir.Auth.SessionCleanup, []},
      # Start a worker by calling: Flixir.Worker.start_link(arg)
      # {Flixir.Worker, arg},
      # Start to serve requests, typically the last entry
      FlixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Flixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
