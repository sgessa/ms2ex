defmodule Ms2ex.GameHandlers.Dismantle do
  alias Ms2ex.{CharacterManager, Dismantle, Inventory, Item, Metadata, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  @default_inventory %{slots: %{}, rewards: %{}}

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Open
  def handle_mode(0x0, _packet, session) do
    send(self(), {:update, %{session | dismantle_inventory: @default_inventory}})
  end

  # Add
  def handle_mode(0x1, packet, session) do
    inventory = get_inventory(session)
    {:ok, character} = CharacterManager.lookup(session.character_id)

    {slot, packet} = get_int(packet)
    {item_uid, packet} = get_long(packet)
    {amount, _packet} = get_int(packet)

    {slot, inventory} = Dismantle.add(inventory, slot, item_uid, amount)
    inventory = Dismantle.update_rewards(character, inventory)

    send(self(), {:update, %{session | dismantle_inventory: inventory}})

    session
    |> push(Packets.Dismantle.add(item_uid, slot, amount))
    |> push(Packets.Dismantle.preview_results(inventory.rewards))
  end

  # Remove
  def handle_mode(0x2, packet, session) do
    inventory = get_inventory(session)
    {:ok, character} = CharacterManager.lookup(session.character_id)

    {item_uid, _packet} = get_long(packet)

    case Enum.find(inventory.slots, fn {_k, {uid, _amount}} -> uid == item_uid end) do
      {slot, _} ->
        inventory = Dismantle.remove(inventory, slot)
        inventory = Dismantle.update_rewards(character, inventory)

        send(self(), {:update, %{session | dismantle_inventory: inventory}})

        session
        |> push(Packets.Dismantle.remove(item_uid))
        |> push(Packets.Dismantle.preview_results(inventory.rewards))

      _ ->
        session
    end
  end

  # Dismantle
  def handle_mode(0x3, _packet, session) do
    inventory = get_inventory(session)
    {:ok, character} = CharacterManager.lookup(session.character_id)

    send(self(), {:update, %{session | dismantle_inventory: @default_inventory}})

    session
    |> consume_items(character)
    |> add_rewards(character)
    |> push(Packets.Dismantle.show_rewards(inventory.rewards))
  end

  # Auto Add
  def handle_mode(0x6, packet, session) do
    {inv_tab, packet} = get_byte(packet)
    {max_rarity, _packet} = get_byte(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    items = Inventory.list_tab_items(character.id, inv_tab)
    auto_add(session, character, max_rarity, items)
  end

  def handle_mode(_mode, _packet, session), do: session

  defp get_inventory(session) do
    Map.get(session, :dismantle_inventory) || @default_inventory
  end

  defp auto_add(session, character, max_rarity, items) do
    items
    |> Enum.take(Dismantle.max_slots())
    |> Enum.map(&Metadata.Items.load/1)
    |> Enum.filter(&(&1.rarity <= max_rarity && &1.metadata.dismantable?))
    |> Enum.reduce(session, fn item, session ->
      inventory = get_inventory(session)
      {slot, inventory} = Dismantle.append(inventory, item.id, item.amount)
      inventory = Dismantle.update_rewards(character, inventory)

      send(self(), {:update, %{session | dismantle_inventory: inventory}})

      session
      |> push(Packets.Dismantle.add(item.id, slot, item.amount))
      |> push(Packets.Dismantle.preview_results(inventory.rewards))
    end)
  end

  defp consume_items(session, character) do
    inventory = get_inventory(session)

    Enum.reduce(inventory.slots, session, fn {_slot, {id, amount}}, session ->
      case Inventory.get(character, id) do
        %Item{} = item ->
          consumed_item = Inventory.consume(item, amount)
          push(session, Packets.InventoryItem.consume(consumed_item))

        _ ->
          session
      end
    end)
  end

  defp add_rewards(session, character) do
    inventory = get_inventory(session)

    Enum.reduce(inventory.rewards, session, fn {item_id, amount}, session ->
      item = %Item{item_id: item_id, amount: amount} |> Metadata.Items.load()

      case Inventory.add_item(character, item) do
        {:ok, result} -> push(session, Packets.InventoryItem.add_item(result))
        _ -> session
      end
    end)
  end
end
