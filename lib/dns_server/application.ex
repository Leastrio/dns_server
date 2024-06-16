defmodule DnsServer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DnsServer.RootHints,
      {Task.Supervisor, name: DnsServer.TaskSupervisor},
      {DnsServer.Listener, port: 2053}
    ]

    opts = [strategy: :one_for_one, name: DnsServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
