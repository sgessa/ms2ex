defmodule Ms2ex.GameHandlers.EquipItem do
  alias Ms2ex.{Equips, Field, Inventory, Metadata, Packets, Registries}

  import Packets.PacketReader
  import Ms2ex.Net.SessionHandler, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Equip
  defp handle_mode(0x0, packet, session) do
    {id, _packet} = get_long(packet)

    with {:ok, character} <- Registries.Characters.lookup(session.character_id),
         %{location: :inventory} = item <- Inventory.get_by(character_id: character.id, id: id) do
      equip_item(character, item, session)
    else
      _ ->
        session
    end
  end

  # Unequip
  defp handle_mode(0x1, packet, session) do
    {id, _packet} = get_long(packet)

    with {:ok, character} <- Registries.Characters.lookup(session.character_id),
         %{location: :equipment} = item <- Inventory.get_by(character_id: character.id, id: id) do
      unequip_item(character, item, session)
    else
      _ ->
        session
    end
  end

  defp equip_item(character, %{location: :inventory} = item, session) do
    item = Metadata.Items.load(item)
    equips = Equips.list(character)

    # find currently equipped item in the same slot and unequip it
    old_items = Equips.find_equipped_in_slot(equips, item)

    session =
      Enum.reduce(old_items, session, fn old_item, session ->
        unequip_item(character, old_item, session)
      end)

    # Equip new item
    with {:ok, item} <- Equips.equip(item) do
      equip_packet = Packets.EquipItem.bytes(character, item)
      Field.broadcast(character, equip_packet)

      push(session, Packets.ItemInventory.remove_item(item.id))
    else
      _ -> session
    end
  end

  defp unequip_item(character, item, session) do
    with {:ok, item} <- Equips.unequip(item) do
      item = Metadata.Items.load(item)

      unequip_packet = Packets.UnequipItem.bytes(character, item.id)
      Field.broadcast(character, unequip_packet)

      push(session, Packets.ItemInventory.add_item({:create, item}))
    else
      _ -> session
    end
  end
end
