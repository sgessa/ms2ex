defmodule Ms2ex.Packets.PacketReader do
  alias Ms2ex.Types.Coord

  def get_bool(packet) do
    <<bool, packet::bytes>> = packet

    if bool == 1 do
      {true, packet}
    else
      {false, packet}
    end
  end

  def get_byte(<<n::integer-8, packet::binary>>), do: {n, packet}

  def get_bytes(packet, n) do
    <<b::little-bytes-size(n), packet::bytes>> = packet
    {b, packet}
  end

  def get_sbyte_coord(packet) do
    {x, packet} = get_sbyte(packet)
    {y, packet} = get_sbyte(packet)
    {z, packet} = get_sbyte(packet)
    {%Coord{x: x, y: y, z: z}, packet}
  end

  def get_short_coord(packet) do
    {x, packet} = get_short(packet)
    {y, packet} = get_short(packet)
    {z, packet} = get_short(packet)
    {%Coord{x: x, y: y, z: z}, packet}
  end

  def get_coord(packet) do
    {x, packet} = get_float(packet)
    {y, packet} = get_float(packet)
    {z, packet} = get_float(packet)
    {%Coord{x: x, y: y, z: z}, packet}
  end

  def get_float(<<n::little-float-32, packet::bytes>>) do
    {n, packet}
  end

  def get_int(<<n::little-signed-integer-32, packet::binary>>), do: {n, packet}

  def get_long(<<n::little-signed-integer-64, packet::binary>>), do: {n, packet}

  def get_sbyte(<<n::little-signed-integer-8, packet::binary>>), do: {n, packet}

  def get_string(packet) do
    {len, packet} = get_short(packet)
    get_bytes(packet, len)
  end

  def get_short(<<n::little-signed-integer-16, packet::binary>>), do: {n, packet}
  def get_ushort(<<n::little-unsigned-integer-16, packet::binary>>), do: {n, packet}

  def get_ustring(packet) do
    {len, packet} = get_short(packet)

    Enum.reduce(0..len, {"", packet}, fn
      0, {_str, packet} ->
        {"", packet}

      _, {str, packet} ->
        {short, packet} = get_short(packet)
        {str <> <<short::utf8>>, packet}
    end)
  end
end
