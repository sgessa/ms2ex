defmodule Ms2ex.GameHandlers.Emote do
  alias Ms2ex.{CharacterManager, Emotes, Field, Inventory, Item, Metadata, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Learn
  defp handle_mode(0x1, packet, session) do
    {item_uid, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %Item{} = item <- Inventory.get(character, item_uid),
         %{metadata: %{skill_id: emote_id}} <- Metadata.Items.load(item),
         consumed_item <- Inventory.consume(item),
         {:ok, _emote} <- Emotes.learn(character, emote_id) do
      session
      |> push(Packets.InventoryItem.consume(consumed_item))
      |> push(Packets.Emote.learn(emote_id))
    end
  end

  # Use
  defp handle_mode(0x2, packet, session) do
    {emote_id, _packet} = get_int(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)
    Field.broadcast_from(character, Packets.Emote.use(character, emote_id), self())
  end
end
