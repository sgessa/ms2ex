defmodule Ms2ex.GameHandlers.EquipItem do
  alias Ms2ex.{Field, Inventory, Metadata, Packets, Registries}

  import Packets.PacketReader
  import Ms2ex.Net.SessionHandler, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Equip
  defp handle_mode(0x0, packet, session) do
    {id, packet} = get_long(packet)
    {slot_name, packet} = get_ustring(packet)
    slot_name = String.to_existing_atom(slot_name)

    if Map.has_key?(Metadata.ItemSlot.mapping(), slot_name) do
      equip_item(id, packet, session)
    else
      session
    end
  rescue
    _ ->
      session
  end

  # Unequip
  defp handle_mode(0x1, packet, session) do
    {id, _packet} = get_long(packet)

    with {:ok, character} <- Registries.Characters.lookup(session.character_id),
         {:ok, item} <- Inventory.unequip(session.character_id, id) do
      item = Metadata.Items.load(item)

      unequip_packet = Packets.UnequipItem.bytes(character, id)
      Field.broadcast(character, unequip_packet, session.pid)

      session
      |> push(Packets.ItemInventory.add_item({:ok, {:create, item}}))
    else
      _ ->
        session
    end
  end

  defp equip_item(_item_id, _packet, session) do
    session
  end
end
