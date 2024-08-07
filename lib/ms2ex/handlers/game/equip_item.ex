defmodule Ms2ex.GameHandlers.EquipItem do
  alias Ms2ex.{Managers, Context, Context, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Equip
  defp handle_mode(0x0, packet, session) do
    {id, packet} = get_long(packet)
    {slot_name, _packet} = get_ustring(packet)

    with true <- Context.Equips.valid_slot?(slot_name),
         {:ok, character} <- Managers.Character.lookup(session.character_id),
         %{location: :inventory} = item <-
           Context.Inventory.get_by(character_id: character.id, id: id) do
      item = Context.Items.load_metadata(item)
      equip_slot = String.to_existing_atom(slot_name)
      equip_item(character, equip_slot, item, session)
    end
  end

  # Unequip
  defp handle_mode(0x1, packet, session) do
    {id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         %{location: :equipment} = item <-
           Context.Inventory.get_by(character_id: character.id, id: id) do
      unequip_item(character, item, session)
    end
  end

  # Swap
  defp handle_mode(0x2, _packet, session), do: session

  defp equip_item(character, equip_slot, %{location: :inventory} = item, session) do
    equips = Context.Equips.list(character)

    # find currently equipped item in the same slot and unequip it
    equipped_items =
      Context.Equips.find_equipped_in_slots(
        equips,
        item.metadata.slots,
        item.inventory_tab,
        equip_slot
      )

    Enum.each(equipped_items, fn item ->
      unequip_item(character, item, session)
    end)

    # Equip new item
    with {:ok, item} <- Context.Equips.equip(item, equip_slot) do
      equip_packet = Packets.EquipItem.bytes(character, item)
      Context.Field.broadcast(character, equip_packet)

      Managers.Character.update(Context.Characters.load_equips(character))
      push(session, Packets.InventoryItem.remove_item(item.id))
    end
  end

  defp unequip_item(character, item, session) do
    with {:ok, item} <- Context.Equips.unequip(item) do
      Managers.Character.update(Context.Characters.load_equips(character))

      item = Context.Items.load_metadata(item)
      unequip_packet = Packets.UnequipItem.bytes(character, item.id)
      Context.Field.broadcast(character, unequip_packet)

      push(session, Packets.InventoryItem.add_item({:create, item}))
    end
  end
end
