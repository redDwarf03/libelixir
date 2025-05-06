defmodule ArchethicClient.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  @doc """
  Starts the ArchethicClient application.

  This function is called when the application starts and is responsible
  for starting the necessary supervision tree, including registries and
  supervisors for managing API subscriptions and tasks.
  """
  def start(_type, _args) do
    childrens = [
      {Registry, name: ArchethicClient.API.SubscriptionRegistry, keys: :unique},
      {Task.Supervisor, name: ArchethicClient.TaskSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: ArchethicClient.API.SubscriptionSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ArchethicClient.Supervisor]
    Supervisor.start_link(childrens, opts)
  end
end
