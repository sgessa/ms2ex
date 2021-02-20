defmodule Ms2ex.GameHandlers.ChatSticker do
  alias Ms2ex.{ChatSticker, ChatStickers, Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Open Window
  defp handle_mode(0x1, _packet, session) do
    # TODO check for expired stickers
    session
  end

  # Use
  defp handle_mode(0x3, packet, session) do
    {sticker_id, packet} = get_int(packet)
    {script, _packet} = get_ustring(packet)

    {:ok, character} = World.get_character(session.world, session.character_id)

    case ChatStickers.get(character, sticker_id) do
      nil -> session
      _ -> push(session, Packets.ChatSticker.use(sticker_id, script))
    end
  end

  # Favorite
  defp handle_mode(0x5, packet, session) do
    {sticker_id, _packet} = get_int(packet)

    {:ok, character} = World.get_character(session.world, session.character_id)

    with %ChatSticker{} = sticker <- ChatStickers.get(character, sticker_id) do
      ChatStickers.favorite(sticker, true)
      push(session, Packets.ChatSticker.favorite(sticker_id))
    else
      _ -> session
    end
  end

  # Unfavorite
  defp handle_mode(0x6, packet, session) do
    {sticker_id, _packet} = get_int(packet)

    {:ok, character} = World.get_character(session.world, session.character_id)

    with %ChatSticker{} = sticker <- ChatStickers.get(character, sticker_id) do
      ChatStickers.favorite(sticker, false)
      push(session, Packets.ChatSticker.unfavorite(sticker_id))
    else
      _ -> session
    end
  end

  defp handle_mode(_mode, _packet, session), do: session
end
