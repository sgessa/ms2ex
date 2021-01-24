defmodule Ms2ex.Packets.UGC do
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
end
