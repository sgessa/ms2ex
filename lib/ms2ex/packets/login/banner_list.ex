defmodule Ms2ex.Packets.BannerList do
  import Ms2ex.Packets.PacketWriter

  def bytes(banners \\ []) do
    blen = Enum.count(banners)

    __MODULE__
    |> build()
    |> put_short(blen)
    |> reduce(banners, fn banner, packet ->
      packet
      |> put_int()
      |> put_ustring(banner.name)
      |> put_ustring(banner.type)
      |> put_ustring()
      |> put_ustring()
      |> put_ustring(banner.url)
      |> put_int(banner.lang)
      |> put_long()
      |> put_long()
    end)
  end
end
