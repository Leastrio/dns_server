defmodule DnsServer.Handler do
  def process_message(msg) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    case query_ip(socket, msg) do
      {:ok, parsed_resp} -> DnsServer.Message.build(parsed_resp)
      :error -> build_error(msg)
    end
  end

  defp build_error(msg) do
    parsed = DnsServer.Message.parse(msg)
    header = %DnsServer.Message.Header{id: parsed.header.id, qr: 1, opcode: 0, aa: 0, tc: 0, rd: 0, ra: 0, z: 0, rcode: 2, qdcount: 1, ancount: 0, nscount: 0, arcount: 0}
    %DnsServer.Message{header: header, questions: parsed.questions, answers: [], authorities: [], additional: []} |> DnsServer.Message.build()
  end

  defp query_ip(socket, msg) do
    root_ip = DnsServer.RootHints.get_next()
    with {:ok, root_resp} <- query_dns_server(socket, root_ip, msg),
        tld_server_ip <- choose_dns_server(socket, root_resp),
        {:ok, tld_resp} <- query_dns_server(socket, tld_server_ip, msg),
        authoritative_server_ip <- choose_dns_server(socket, tld_resp) do
          query_dns_server(socket, authoritative_server_ip, msg)
    else
      _ -> :error
    end
  end

  defp query_dns_server(socket, ip, msg) do
    with :ok <- :gen_udp.send(socket, ip, 53, msg),
      {:ok, {_ip, _port, data}} <- :gen_udp.recv(socket, 0),
      parsed_data <- DnsServer.Message.parse(data) do
        {:ok, parsed_data}
      else
        _ -> :error
      end
  end

  defp choose_dns_server(socket, resp) do
    {:label, authority} = resp.authorities
      |> Enum.random()
      |> Map.get(:rdata)
    
    reply = if not Enum.any?(resp.additional, fn rr -> rr.type == 1 end) do
      header = %DnsServer.Message.Header{id: resp.header.id, qr: 0, opcode: 0, aa: 0, tc: 0, rd: 0, ra: 0, z: 0, rcode: 0, qdcount: 1, ancount: 0, nscount: 0, arcount: 0}
      question = %DnsServer.Message.Question{name: authority, type: 1, class: 1}
      msg = %DnsServer.Message{header: header, questions: [question], answers: [], authorities: [], additional: []} |> DnsServer.Message.build()
      {:ok, data} = query_ip(socket, msg)

      data.answers
    else
      resp.additional
    end
    
    reply
    |> Enum.filter(fn rr -> rr.type == 1 end)
    |> Enum.random()
    |> Map.get(:rdata)
    |> elem(1)
    |> :binary.bin_to_list()
    |> List.to_tuple()
  end
end
