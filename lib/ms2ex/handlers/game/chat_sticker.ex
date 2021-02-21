defmodule Ms2ex.GameHandlers.ChatSticker do
  alias Ms2ex.{ChatSticker, ChatStickers, Metadata, Packets, World}

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

  # Chat
  defp handle_mode(0x3, packet, session) do
    {sticker_id, packet} = get_int(packet)
    {script, _packet} = get_ustring(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         {:ok, sticker} <- Metadata.ChatStickers.lookup(sticker_id),
         %ChatSticker{} <- ChatStickers.get(character, sticker.group_id) do
      push(session, Packets.ChatSticker.chat(sticker_id, script))
    else
      _ -> session
    end
  end

  # Group Chat
  defp handle_mode(0x4, packet, session) do
    {sticker_id, packet} = get_int(packet)
    {chat_name, _packet} = get_ustring(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         {:ok, sticker} <- Metadata.ChatStickers.lookup(sticker_id),
         %ChatSticker{} <- ChatStickers.get(character, sticker.group_id) do
      push(session, Packets.ChatSticker.group_chat(sticker_id, chat_name))
    else
      _ -> session
    end
  end

  # Favorite
  defp handle_mode(0x5, packet, session) do
    {sticker_id, _packet} = get_int(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         {:ok, sticker} <- Metadata.ChatStickers.lookup(sticker_id),
         %ChatSticker{} <- ChatStickers.get(character, sticker.group_id) do
      # TODO???
      push(session, Packets.ChatSticker.favorite(sticker_id))
    else
      _ -> session
    end
  end

  # Unfavorite
  defp handle_mode(0x6, packet, session) do
    {sticker_id, _packet} = get_int(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         {:ok, sticker} <- Metadata.ChatStickers.lookup(sticker_id),
         %ChatSticker{} <- ChatStickers.get(character, sticker.group_id) do
      # TODO???
      push(session, Packets.ChatSticker.unfavorite(sticker_id))
    else
      _ -> session
    end
  end

  defp handle_mode(_mode, _packet, session), do: session
end
