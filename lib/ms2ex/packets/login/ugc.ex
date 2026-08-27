defmodule Ms2ex.Packets.Ugc do
  import Ms2ex.Packets.PacketWriter

  def set_endpoint() do
    config = Application.get_env(:ms2ex, Ms2ex)

    __MODULE__
    |> build()
    |> put_byte(0x11)
    |> put_ustring(config[:ugc].endpoint)
    |> put_ustring(config[:ugc].resource)
    |> put_ustring(config[:ugc].locale)
    |> put_byte(0x2)
  end

  def put_ugc(packet) do
    packet
    |> put_long
    |> put_ustring()
    |> put_ustring()
    |> put_byte()
    |> put_int()
    |> put_long()
    |> put_long()
    |> put_ustring()
    |> put_long()
    |> put_ustring()
    |> put_byte()
  end

  @load_banner 0x12
  def load do
    __MODULE__
    |> build()
    |> put_byte(@load_banner)
    |> put_int(0)
    |> put_int(0)
    |> put_int(0)
  end
end
