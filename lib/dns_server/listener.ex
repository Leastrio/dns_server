defmodule DnsServer.Listener do
  require Logger
  use GenServer
  alias DnsServer.Message

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    Logger.info("Listening for packets...")
    :gen_udp.open(port, [:binary])
  end

  def handle_info({:udp, _pid, host, port, msg}, socket) do
    Task.Supervisor.start_child(DnsServer.TaskSupervisor, fn ->
      Logger.info("Recieved message...")
      Message.parse(msg) |> IO.inspect()
      :gen_udp.send(socket, host, port, "")
    end)
    {:noreply, socket}
  end
end
