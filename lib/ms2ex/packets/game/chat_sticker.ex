defmodule Ms2ex.Packets.ChatSticker do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x0,
    expired_sticker_notification: 0x1,
    add: 0x2,
    use: 0x3,
    favorite: 0x5,
    unfavorite: 0x6
  }

  def load(stickers) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_short()
    |> put_short(length(stickers))
    |> reduce(stickers, fn sticker_id, packet ->
      packet
      |> put_int(sticker_id)
      |> put_long(9_223_372_036_854_775_807)
    end)
  end

  def expired_notification() do
    __MODULE__
    |> build()
    |> put_byte(@modes.expired_sticker_notification)
    |> put_int()
    |> put_int(1)
  end

  def add(item_id, group_id, expiration) do
    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(item_id)
    |> put_int(1)
    |> put_int(group_id)
    |> put_long(expiration)
  end

  def use(sticker_id, script) do
    __MODULE__
    |> build()
    |> put_byte(@modes.use)
    |> put_int(sticker_id)
    |> put_ustring(script)
    |> put_byte()
  end

  def favorite(sticker_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.favorite)
    |> put_int(sticker_id)
  end

  def unfavorite(sticker_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.unfavorite)
    |> put_int(sticker_id)
  end
end
