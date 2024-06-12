defmodule DnsServer.Message do
  defmodule Header do
    defstruct [:id, :qr, :opcode, :aa, :tc, :rd, :ra, :z, :rcode, :qdcount, :ancount, :nscount, :arcount]

    def parse(<<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, z::3, rcode::4, qdcount::16, ancount::16, nscount::16, arcount::16>>) do
      %__MODULE__{id: id, qr: qr, opcode: opcode, aa: aa, tc: tc, rd: rd, ra: ra, z: z, rcode: rcode, qdcount: qdcount, ancount: ancount, nscount: nscount, arcount: arcount}
    end

    def build(%__MODULE__{} = s) do
      <<s.id::16, s.qr::1, s.opcode::4, s.aa::1, s.tc::1, s.rd::1, s.ra::1, s.z::3, s.rcode::4, s.qdcount::16, s.ancount::16, s.nscount::16, s.arcount::16>>
    end
  end

  defmodule Question do
    defstruct [:name, :type, :class]

    def parse(data, qdcount), do: parse(data, qdcount, [])
    defp parse(data, 0, questions), do: {questions, data}
    defp parse(data, count, questions) do
      {name, <<type::16, class::16, rest::binary>>} = DnsServer.Message.parse_name(data, [])
      parse(rest, count - 1, [%__MODULE__{name: name, type: type, class: class} | questions])
    end

    def build(%__MODULE__{} = s) do
      Enum.reduce(s.name, <<>>, fn label, acc -> 
        l_length = String.length(label)
        acc <> <<l_length, label>>
      end) <> <<0>> <> <<s.type::16, s.class::16>>
    end
  end

  defmodule ResourceRecord do
    defstruct [:name, :type, :class, :ttl, :rdlength, :rdata]

    def parse(data, count), do: parse(data, count, [])
    defp parse(data, 0, records), do: {records, data}
    defp parse(data, count, records) do
      {name, <<type::16, class::16, ttl::32, rdlength::16, rdata::bitstring-size(rdlength * 8), rest::binary>>} = DnsServer.Message.parse_name(data, [])
      parse(rest, count - 1, [%__MODULE__{name: name, type: type, class: class, ttl: ttl, rdlength: rdlength, rdata: rdata} | records])
    end
  end

  def parse(<<header::bitstring-size(96), rest::binary>>) do
    header = Header.parse(header)
    {questions, rest} = Question.parse(rest, header.qdcount)
    {answers, rest} = ResourceRecord.parse(rest, header.ancount)
    {authorities, rest} = ResourceRecord.parse(rest, header.nscount)
    {additional, _} = ResourceRecord.parse(rest, header.arcount)

    %{header: header, questions: questions, answers: answers, authorities: authorities, additional: additional}
  end

  def parse_name(<<0, rest::binary>>, labels), do: {Enum.reverse(labels), rest}
  def parse_name(<<len::8, rest::binary>>, labels) do
    <<label::binary-size(len), rest::binary>> = rest
    parse_name(rest, [label | labels])
  end
end
