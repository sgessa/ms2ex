defmodule Ms2ex.GameHandlers.EquipItem do
  alias Ms2ex.{Characters, Equips, Field, Inventory, Metadata, Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Equip
  defp handle_mode(0x0, packet, session) do
    {id, packet} = get_long(packet)
    {slot_name, _packet} = get_ustring(packet)

    with true <- Equips.valid_slot?(slot_name),
         {:ok, character} <- World.get_character(session.character_id),
         %{location: :inventory} = item <- Inventory.get_by(character_id: character.id, id: id) do
      item = Metadata.Items.load(item)
      equip_slot = String.to_existing_atom(slot_name)
      equip_item(character, equip_slot, item, session)
    else
      _ ->
        session
    end
  end

  # Unequip
  defp handle_mode(0x1, packet, session) do
    {id, _packet} = get_long(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         %{location: :equipment} = item <- Inventory.get_by(character_id: character.id, id: id) do
      unequip_item(character, item, session)
    else
      _ ->
        session
    end
  end

  # Swap
  defp handle_mode(0x2, _packet, session), do: session

  defp equip_item(character, equip_slot, %{location: :inventory} = item, session) do
    equips = Equips.list(character)

    # find currently equipped item in the same slot and unequip it
    old_items = Equips.find_equipped_in_slot(equips, equip_slot, item)

    session =
      Enum.reduce(old_items, session, fn old_item, session ->
        unequip_item(character, old_item, session)
      end)

    # Equip new item
    with {:ok, item} <- Equips.equip(equip_slot, item) do
      equip_packet = Packets.EquipItem.bytes(character, item)
      Field.broadcast(character, equip_packet)

      # Update registry
      World.update_character(Characters.load_equips(character))

      push(session, Packets.InventoryItem.remove_item(item.id))
    else
      _ -> session
    end
  end

  defp unequip_item(character, item, session) do
    with {:ok, item} <- Equips.unequip(item) do
      # Update registry
      World.update_character(Characters.load_equips(character))

      item = Metadata.Items.load(item)
      unequip_packet = Packets.UnequipItem.bytes(character, item.id)
      Field.broadcast(character, unequip_packet)

      push(session, Packets.InventoryItem.add_item({:create, item}))
    else
      _ -> session
    end
  end
end
