defmodule Ms2ex.GameHandlers.Dismantle do
  alias Ms2ex.{CharacterManager, Context, Dismantle, Packets, Schema}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @default_inventory %{slots: %{}, rewards: %{}}

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Open
  def handle_mode(0x0, _packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)
    CharacterManager.update(%{character | dismantle_inventory: @default_inventory})
  end

  # Add
  def handle_mode(0x1, packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)
    inventory = character.dismantle_inventory

    {slot, packet} = get_int(packet)
    {item_uid, packet} = get_long(packet)
    {amount, _packet} = get_int(packet)

    {slot, inventory} = Dismantle.add(inventory, slot, item_uid, amount)
    inventory = Dismantle.update_rewards(character, inventory)

    CharacterManager.update(%{character | dismantle_inventory: inventory})

    session
    |> push(Packets.Dismantle.add(item_uid, slot, amount))
    |> push(Packets.Dismantle.preview_results(inventory.rewards))
  end

  # Remove
  def handle_mode(0x2, packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)
    inventory = character.dismantle_inventory

    {item_uid, _packet} = get_long(packet)

    with {slot, _} <- Enum.find(inventory.slots, fn {_k, {uid, _amount}} -> uid == item_uid end) do
      inventory = Dismantle.remove(inventory, slot)
      inventory = Dismantle.update_rewards(character, inventory)

      CharacterManager.update(%{character | dismantle_inventory: inventory})

      session
      |> push(Packets.Dismantle.remove(item_uid))
      |> push(Packets.Dismantle.preview_results(inventory.rewards))
    end
  end

  # Dismantle
  def handle_mode(0x3, _packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)
    inventory = character.dismantle_inventory

    consume_items(session, character)
    add_rewards(session, character)

    CharacterManager.update(%{character | dismantle_inventory: @default_inventory})

    push(session, Packets.Dismantle.show_rewards(inventory.rewards))
  end

  # Auto Add
  def handle_mode(0x6, packet, session) do
    {inv_tab, packet} = get_byte(packet)
    {max_rarity, _packet} = get_byte(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    items = Context.Inventory.list_tab_items(character.id, inv_tab)
    inventory = auto_add(session, character, max_rarity, items)
    CharacterManager.update(%{character | dismantle_inventory: inventory})
  end

  def handle_mode(_mode, _packet, session), do: session

  defp auto_add(session, character, max_rarity, items) do
    items
    |> Enum.take(Dismantle.max_slots())
    |> Enum.map(&Context.Items.load_metadata/1)
    |> Enum.filter(&(&1.rarity <= max_rarity && &1.metadata.dismantable?))
    |> Enum.reduce(character.inventory, fn item, inventory ->
      {slot, inventory} = Dismantle.append(inventory, item.id, item.amount)
      inventory = Dismantle.update_rewards(character, inventory)

      session
      |> push(Packets.Dismantle.add(item.id, slot, item.amount))
      |> push(Packets.Dismantle.preview_results(inventory.rewards))

      inventory
    end)
  end

  defp consume_items(session, character) do
    inventory = character.dismantle_inventory

    Enum.each(inventory.slots, fn {_slot, {id, amount}} ->
      with %Schema.Item{} = item <- Context.Inventory.get(character, id) do
        consumed_item = Context.Inventory.consume(item, amount)
        push(session, Packets.InventoryItem.consume(consumed_item))
      end
    end)
  end

  defp add_rewards(session, character) do
    inventory = character.dismantle_inventory

    Enum.each(inventory.rewards, fn {item_id, amount} ->
      item = Context.Items.init(item_id, %{amount: amount})

      with {:ok, result} <- Context.Inventory.add_item(character, item) do
        push(session, Packets.InventoryItem.add_item(result))
      end
    end)
  end
end
