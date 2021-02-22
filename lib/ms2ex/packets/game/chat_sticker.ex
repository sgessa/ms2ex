defmodule Ms2ex.Packets.ChatSticker do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x0,
    expired_sticker_notification: 0x1,
    add: 0x2,
    chat: 0x3,
    group_chat: 0x4,
    favorite: 0x5,
    unfavorite: 0x6
  }

  @unlimited 9_223_372_036_854_775_807
  def load(favorite_stickers, sticker_groups) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_short(length(favorite_stickers))
    |> reduce(favorite_stickers, fn sticker_id, packet ->
      put_int(packet, sticker_id)
    end)
    |> put_short(length(sticker_groups))
    |> reduce(sticker_groups, fn group_id, packet ->
      packet
      |> put_int(group_id)
      # TODO expiration
      |> put_long(@unlimited)
    end)
  end

  def expired_notification() do
    __MODULE__
    |> build()
    |> put_byte(@modes.expired_sticker_notification)
    |> put_int()
    |> put_int(1)
  end

  def add(item_id, group_id, expiration \\ @unlimited) do
    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(item_id)
    |> put_int(1)
    |> put_int(group_id)
    |> put_long(expiration)
  end

  def chat(sticker_id, script) do
    __MODULE__
    |> build()
    |> put_byte(@modes.chat)
    |> put_int(sticker_id)
    |> put_ustring(script)
    |> put_byte()
  end

  def group_chat(sticker_id, chat_name) do
    __MODULE__
    |> build()
    |> put_byte(@modes.group_chat)
    |> put_int(sticker_id)
    |> put_ustring(chat_name)
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
