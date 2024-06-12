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
      {name, <<type::16, class::16, rest::binary>>} = parse_name(data, [])
      parse(rest, count - 1, [%__MODULE__{name: name, type: type, class: class} | questions])
    end

    defp parse_name(<<0, rest::binary>>, labels), do: {Enum.reverse(labels), rest}
    defp parse_name(<<len::8, rest::binary>>, labels) do
      <<label::binary-size(len), rest::binary>> = rest
      parse_name(rest, [label | labels])
    end

    def build(%__MODULE__{} = s) do
      Enum.reduce(s.name, <<>>, fn label, acc -> 
        l_length = String.length(label)
        acc <> <<l_length, label>>
      end) <> <<0>> <> <<s.type::16, s.class::16>>
    end
  end

  def parse(<<header::bitstring-size(96), rest::binary>>) do
    header = Header.parse(header)
    {questions, rest} = Question.parse(rest, header.qdcount)

    {header, questions}
  end

  def build() do
    build_header() <> build_question() <> build_answer()
  end
  
  defp build_header() do
    <<1234::16, 1::1, 0::4, 0::1, 0::1, 0::1, 0::1, 0::3, 0::4, 1::16, 1::16, 0::16, 0::16>>
  end

  defp build_question() do 
    <<12, "codecrafters", 2, "io", 0, 1::16, 1::16>>
  end
  
  defp build_answer() do
    <<12, "codecrafters", 2, "io", 0, 1::16, 1::16, 60::32, 4::16, 8::8, 8::8, 8::8, 8::8>>
  end
end
