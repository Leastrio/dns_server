defmodule DnsServer.Message do
  defstruct [:header, :questions, :answers, :authorities, :additional]
  
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

    def parse(data, qdcount, buf), do: parse(data, qdcount, [], buf)
    defp parse(data, 0, questions, _buf), do: {questions, data}
    defp parse(data, count, questions, buf) do
      {name, <<type::16, class::16, rest::binary>>} = DnsServer.Message.parse_name(data, [], buf)
      parse(rest, count - 1, [%__MODULE__{name: name, type: type, class: class} | questions], buf)
    end

    def build(%__MODULE__{} = s) do
      DnsServer.Message.build_name(s.name) <> <<s.type::16, s.class::16>>
    end
  end

  defmodule ResourceRecord do
    defstruct [:name, :type, :class, :ttl, :rdlength, :rdata]

    def parse(data, count, buf), do: parse(data, count, [], buf)
    defp parse(data, 0, records, _buf), do: {records, data}
    defp parse(data, count, records, buf) do
      {name, <<type::16, class::16, ttl::32, rdlength::16, rdata::binary-size(rdlength), rest::binary>>} = DnsServer.Message.parse_name(data, [], buf)
      rdata = if type == 2 do
        {ns_names, _} = DnsServer.Message.parse_name(rdata, [], buf)
        {:label, ns_names}
      else
        {:data, rdata}
      end
      parse(rest, count - 1, [%__MODULE__{name: name, type: type, class: class, ttl: ttl, rdlength: rdlength, rdata: rdata} | records], buf)
    end

    def build(%__MODULE__{} = s) do
      DnsServer.Message.build_name(s.name) <> <<s.type::16, s.class::16, s.ttl::32>> <> build_rdata(s.rdata, s.rdlength)
    end

    defp build_rdata({:label, labels}, _len) do
      name = DnsServer.Message.build_name(labels)
      len = byte_size(name)
      <<len::16>> <> name
    end
    defp build_rdata({:data, rdata}, len), do: <<len::16, rdata::binary-size(len)>>
  end

  def parse(<<header::bitstring-size(96), rest::binary>> = buf) do
    header = Header.parse(header)
    {questions, rest} = Question.parse(rest, header.qdcount, buf)
    {answers, rest} = ResourceRecord.parse(rest, header.ancount, buf)
    {authorities, rest} = ResourceRecord.parse(rest, header.nscount, buf)
    {additional, _} = ResourceRecord.parse(rest, header.arcount, buf)

    %__MODULE__{header: header, questions: questions, answers: answers, authorities: authorities, additional: additional}
  end

  def parse_name(<<0::8, rest::binary>>, labels, _buf), do: {Enum.reverse(labels), rest}
  def parse_name(<<1::1, 1::1, offset::14, rest::binary>>, labels, buf) do
    <<_::binary-size(offset), part::binary>> = buf
    {pointer_labels, _} = parse_name(part, labels, buf)
    {pointer_labels, rest}
  end
  def parse_name(<<len::8, rest::binary>>, labels, buf) do
    <<label::binary-size(len), rest::binary>> = rest
    parse_name(rest, [label | labels], buf)
  end

  def build_name(labels) do
    Enum.reduce(labels, <<>>, fn label, acc -> 
      l_length = String.length(label)
      acc <> <<l_length::integer-size(8), label::binary-size(l_length)>>
    end) <> <<0>>
  end

  def build(msg) do
    header = msg.header |> Header.build()
    questions = Enum.reduce(msg.questions, <<>>, fn q, acc -> acc <> Question.build(q) end)
    answers = Enum.reduce(msg.answers, <<>>, fn a, acc -> acc <> ResourceRecord.build(a) end)
    authorities = Enum.reduce(msg.authorities, <<>>, fn a, acc -> acc <> ResourceRecord.build(a) end)
    additional = Enum.reduce(msg.additional, <<>>, fn a, acc -> acc <> ResourceRecord.build(a) end)

    header <> questions <> answers <> authorities <> additional
  end
end
