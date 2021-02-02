defmodule Ms2ex.Packets.PacketWriter do
  def build(module) do
    name =
      module
      |> to_string()
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()
      |> String.upcase()

    opcode = Ms2ex.Packets.name_to_opcode(:send, name)
    put_short(<<>>, opcode)
  end

  def put_bool(packet, true), do: packet <> <<1>>
  def put_bool(packet, false), do: packet <> <<0>>
  def put_byte(packet, byte \\ 0x0), do: packet <> <<byte>>
  def put_bytes(packet, b), do: packet <> <<b::bytes>>

  def put_coord(packet, %{x: x, y: y, z: z}) do
    packet
    |> put_float(x)
    |> put_float(y)
    |> put_float(z)
  end

  def put_coord(packet) do
    packet
    |> put_float()
    |> put_float()
    |> put_float()
  end

  def put_deflated(packet, data, length) when length <= 4 do
    packet
    |> put_int(length)
    |> put_bytes(data)
  end

  def put_deflated(packet, data, length) do
    deflated_data = deflate(data)

    packet
    |> put_int(byte_size(deflated_data) + 4)
    |> put_int_big(length)
    |> put_bytes(deflated_data)
  end

  def put_ecto_enum(packet, type, atom) do
    int = Keyword.get(type.__enum_map__(), atom)
    put_byte(packet, int)
  end

  def put_float(packet, number \\ 0x0, size \\ 32) do
    packet <> <<number::little-float-size(size)>>
  end

  def put_int(packet, int \\ 0x0), do: packet <> <<int::little-integer-32>>

  def put_int_big(packet, int \\ 0x0), do: packet <> <<int::big-integer-32>>

  def put_ip_address(packet, addr) do
    addr =
      addr
      |> String.split(".")
      |> Enum.map(&String.to_integer(&1))
      |> Enum.map(&<<&1>>)
      |> Enum.join()

    packet <> addr
  end

  def put_long(packet, int \\ 0x0), do: packet <> <<int::little-integer-64>>

  def put_short(packet, short \\ 0x0), do: packet <> <<short::little-integer-16>>

  def put_short_coord(packet, %{x: x, y: y, z: z}) do
    packet
    |> put_short(x)
    |> put_short(y)
    |> put_short(z)
  end

  def put_string(packet, str \\ "") do
    packet
    |> put_short(byte_size(str))
    |> put_bytes(str)
  end

  def put_time(packet, time \\ nil)

  def put_time(packet, nil), do: put_long(packet)

  def put_time(packet, time) do
    put_long(packet, DateTime.to_unix(time))
  end

  def put_uchar(packet, ""), do: packet

  def put_uchar(packet, <<char::utf8, str::bytes>>) do
    packet
    |> put_short(char)
    |> put_uchar(str)
  end

  def put_ushort(packet, short \\ 0x0), do: packet <> <<short::little-unsigned-integer-16>>

  def put_ustring(packet, str \\ "") do
    packet
    |> put_short(String.length(str))
    |> put_uchar(str)
  end

  def put_static_packet(packet, static) do
    static =
      static
      |> String.split(" ")
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    packet <> static
  end

  def deflate(data) do
    zlib = :zlib.open()
    :ok = :zlib.deflateInit(zlib)
    deflated = :zlib.deflate(zlib, data, :sync)
    :zlib.close(zlib)

    deflated = Enum.into(deflated, <<>>)
    <<deflated::little-bytes>>
  end

  def reduce(packet, enum, fun) do
    Enum.reduce(enum, packet, fun)
  end
end
