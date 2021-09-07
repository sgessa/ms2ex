defmodule Ms2ex.GameHandlers.PickupItem do
  require Logger

  alias Ms2ex.{Field, Inventory, Metadata, Net, Packets, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {object_id, _packet} = get_int(packet)

    {:ok, character} = World.get_character(session.character_id)

    # TODO check that user inventory is not full

    with {:ok, item} <- Field.remove_item(character, object_id),
         item <- Metadata.Items.load(item),
         {:ok, result} <- Inventory.add_item(character, item) do
      Field.broadcast(character, Packets.FieldPickupItem.bytes(character, item))
      push(session, Packets.InventoryItem.add_item(result))
    else
      _ ->
        session
    end
  end
end
