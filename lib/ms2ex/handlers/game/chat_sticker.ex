defmodule Ms2ex.GameHandlers.ChatSticker do
  alias Ms2ex.{Managers, Context, ProtoMetadata, Packets, Schema}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Open Window
  defp handle_mode(0x1, _packet, _session) do
    # TODO check for expired stickers
  end

  # Chat
  defp handle_mode(0x3, packet, session) do
    {sticker_id, packet} = get_int(packet)
    {script, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, sticker} <- ProtoMetadata.ChatStickers.lookup(sticker_id),
         %Schema.ChatStickerGroup{} <- Context.ChatStickers.get(character, sticker.group_id) do
      push(session, Packets.ChatSticker.chat(sticker_id, script))
    end
  end

  # Group Chat
  defp handle_mode(0x4, packet, session) do
    {sticker_id, packet} = get_int(packet)
    {chat_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, sticker} <- ProtoMetadata.ChatStickers.lookup(sticker_id),
         %Schema.ChatStickerGroup{} <- Context.ChatStickers.get(character, sticker.group_id) do
      push(session, Packets.ChatSticker.group_chat(sticker_id, chat_name))
    end
  end

  # Favorite
  defp handle_mode(0x5, packet, session) do
    {sticker_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, sticker} <- ProtoMetadata.ChatStickers.lookup(sticker_id),
         %Schema.ChatStickerGroup{} <- Context.ChatStickers.get(character, sticker.group_id) do
      Context.ChatStickers.favorite(character, sticker_id, sticker.group_id)
      push(session, Packets.ChatSticker.favorite(sticker_id))
    end
  end

  # Unfavorite
  defp handle_mode(0x6, packet, session) do
    {sticker_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, sticker} <- ProtoMetadata.ChatStickers.lookup(sticker_id),
         %Schema.ChatStickerGroup{} <- Context.ChatStickers.get(character, sticker.group_id) do
      Context.ChatStickers.unfavorite(character, sticker_id)
      push(session, Packets.ChatSticker.unfavorite(sticker_id))
    end
  end

  defp handle_mode(_mode, _packet, session), do: session
end
