defmodule DnsServer.RootHints do
  use GenServer

  @path to_string(:code.priv_dir(:dns_server)) <> "/named.root"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    ips = File.read!(@path)
      |> String.split("\n")
      |> Enum.flat_map(fn line -> 
        with false <- String.starts_with?(line, ";"),
             [_name, _ttl, "A", ip] <- String.split(line, " ", trim: true) do
              ip = ip |> String.split(".") |> Enum.map(&String.to_integer/1) |> List.to_tuple()
              [ip]
        else
          _ -> []
        end
      end)
    {:ok, {0, ips}}
  end

  def handle_call(:get_next, _from, {idx, ips}) do
    ip = Enum.at(ips, idx)
    new_idx = rem(idx + 1, length(ips))
    {:reply, ip, {new_idx, ips}}
  end

  def get_next() do
    GenServer.call(__MODULE__, :get_next)
  end
end
