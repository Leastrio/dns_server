defmodule DnsServer.Handler do
  def process_message(msg) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    root_ip = DnsServer.RootHints.get_next() |> IO.inspect()
    with :ok <- :gen_udp.send(socket, root_ip, 53, msg),
        {:ok, {_ip, _port, data}} <- :gen_udp.recv(socket, 0),
        parsed_data <- DnsServer.Message.parse(data) do
          DnsServer.Message.build(parsed_data)
        end
  end
end
