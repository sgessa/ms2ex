defmodule Ms2ex.GameHandlers.Emote do
  alias Ms2ex.{Managers, Context, Context, Packets, Schema}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Learn
  defp handle_mode(0x1, packet, session) do
    {item_uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         %Schema.Item{} = item <- Context.Inventory.get(character, item_uid),
         %{metadata: %{skill_id: emote_id}} <- Context.Items.load_metadata(item),
         consumed_item <- Context.Inventory.consume(item),
         {:ok, _emote} <- Context.Emotes.learn(character, emote_id) do
      session
      |> push(Packets.InventoryItem.consume(consumed_item))
      |> push(Packets.Emote.learn(emote_id))
    end
  end

  # Use
  defp handle_mode(0x2, packet, session) do
    {emote_id, _packet} = get_int(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)
    Context.Field.broadcast_from(character, Packets.Emote.use(character, emote_id), self())
  end
end
