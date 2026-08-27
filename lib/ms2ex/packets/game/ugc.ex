defmodule Ms2ex.Packets.Ugc do
  import Ms2ex.Packets.PacketWriter

  @load_banner 0x12

  # empty banner load: no rolling images, no banners
  def load do
    __MODULE__
    |> build()
    |> put_byte(@load_banner)
    |> put_int(0)
    |> put_int(0)
    |> put_int(0)
  end
end
