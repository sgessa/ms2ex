defmodule Ms2ex.GameHandlers.Emote do
  alias Ms2ex.{Emotes, Field, Inventory, Metadata, Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Learn
  defp handle_mode(0x1, packet, session) do
    {item_uid, _packet} = get_long(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         %Inventory.Item{} = item <- Inventory.get(character, item_uid),
         %{metadata: %{skill_id: emote_id}} <- Metadata.Items.load(item),
         {:ok, _emote} <- Emotes.learn(character, emote_id) do
      push(session, Packets.Emote.learn(emote_id))
    else
      _ ->
        session
    end
  end

  # Use
  defp handle_mode(0x2, packet, session) do
    {emote_id, _packet} = get_int(packet)

    {:ok, character} = World.get_character(session.world, session.character_id)
    Field.broadcast(character, Packets.Emote.use(character, emote_id), self())

    session
  end
end
