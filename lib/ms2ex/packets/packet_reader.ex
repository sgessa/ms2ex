defmodule Ms2ex.Packets.PacketReader do
  def get_byte(<<n::integer-8, packet::binary>>), do: {n, packet}

  def get_bytes(packet, n) do
    <<b::bytes-size(n), packet::little-bytes>> = packet
    {b, packet}
  end

  def get_short_coord(packet) do
    {x, packet} = get_short(packet)
    {y, packet} = get_short(packet)
    {z, packet} = get_short(packet)
    {{x, y, z}, packet}
  end

  def get_coord(packet) do
    {x, packet} = get_float(packet)
    {y, packet} = get_float(packet)
    {z, packet} = get_float(packet)
    {{x, y, z}, packet}
  end

  def get_float(<<n::little-float-32, packet::bytes>>) do
    {n, packet}
  end

  def get_int(<<n::little-integer-32, packet::binary>>), do: {n, packet}
  def get_long(<<n::little-integer-64, packet::binary>>), do: {n, packet}

  def get_string(packet) do
    {len, packet} = get_short(packet)
    get_bytes(packet, len)
  end

  def get_short(<<n::little-integer-16, packet::binary>>), do: {n, packet}
  def get_ushort(<<n::little-unsigned-integer-16, packet::binary>>), do: {n, packet}

  def get_ustring(packet) do
    {len, packet} = get_short(packet)

    Enum.reduce(1..len, {"", packet}, fn _, {str, packet} ->
      {short, packet} = get_short(packet)
      {str <> <<short::utf8>>, packet}
    end)
  end
end
