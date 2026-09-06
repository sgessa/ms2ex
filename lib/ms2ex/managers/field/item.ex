defmodule Ms2ex.Managers.Field.Item do
  import Ms2ex.Net.SenderSession, only: [push: 2]

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  def pickup_item(character, item, state) do
    credit = consumable_credit(item)

    if credit do
      apply_credit(character, credit, item.amount)
      remove_item(character, item, state)
    else
      pickup_inventory_item(character, item, state)
    end
  end

  # field items that convert directly into a wallet balance or a stat
  defp consumable_credit(item) do
    cond do
      Context.Items.mesos?(item) -> {:wallet, :mesos}
      Context.Items.valor_token?(item) -> {:wallet, :valor_tokens}
      Context.Items.merets?(item) -> {:wallet, :merets}
      Context.Items.rue?(item) -> {:wallet, :rues}
      Context.Items.havi_fruit?(item) -> {:wallet, :havi_fruits}
      Context.Items.sp?(item) -> {:stat, :spirit}
      Context.Items.stamina?(item) -> {:stat, :stamina}
      true -> nil
    end
  end

  defp apply_credit(character, {:wallet, currency}, amount),
    do: Context.Wallets.update(character, currency, amount)

  defp apply_credit(character, {:stat, stat}, amount),
    do: Managers.Character.cast(character, {:increase_stats, [{stat, amount}]})

  defp pickup_inventory_item(character, item, state) do
    item =
      item
      |> Context.Items.load_metadata()
      |> Context.Items.bind_if_needed(:loot)

    case Managers.Inventory.add_item(character, item) do
      {:ok, result} ->
        {_status, inventory_item} = result
        push(character, Packets.InventoryItem.add_item(result, character))
        push(character, Packets.InventoryItem.mark_item_new(inventory_item))
        Managers.Quest.notify_item_acquired(character, inventory_item)

        # pickup-count quest conditions; code param carries the item id
        Managers.Quest.update_conditions(
          character.id,
          :item_pickup,
          inventory_item.amount,
          "",
          0,
          "",
          inventory_item.item_id
        )

        remove_item(character, item, state)

      # the inventory cannot hold the item; it stays on the field
      {:error, _changeset} ->
        state
    end
  end

  defp remove_item(character, item, state) do
    Context.Field.broadcast(state.topic, Packets.FieldPickupItem.bytes(character, item))
    Context.Field.broadcast(state.topic, Packets.FieldRemoveItem.bytes(item.object_id))

    items = Map.delete(state.items, item.object_id)
    %{state | items: items}
  end

  def drop_item(character, item, state), do: drop_item(character, item, character.position, state)

  def drop_item(character, item, position, state) do
    {object_id, state} = Managers.Field.next_local_id(state)

    item = %{
      item
      | position: position,
        object_id: object_id,
        source_object_id: character.object_id
    }

    Context.Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))
    store(state, item)
  end

  def add_mob_drop(mob, item, receiver \\ nil, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    receiver = receiver || mob.first_attacker || mob.last_attacker

    item = %{
      item
      | position: drop_position(mob),
        object_id: object_id,
        lock_character_id: if(receiver, do: receiver.id, else: 0),
        mob_drop?: true,
        source_object_id: mob.object_id,
        target_object_id: if(receiver, do: receiver.object_id, else: 0)
    }

    Context.Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))
    store(state, item)
  end

  # metadata is re-read from the storage cache when the item is picked up;
  # it is not kept in the field state
  defp store(state, item) do
    items = Map.put(state.items, item.object_id, %{item | metadata: nil})
    %{state | items: items}
  end

  # scatter drops around the corpse
  defp drop_position(mob) do
    case get_in(mob.npc.metadata, [:drop_info, :drop_distance_random]) do
      radius when is_integer(radius) and radius > 0 ->
        %{
          mob.position
          | x: mob.position.x + jitter(radius),
            y: mob.position.y + jitter(radius)
        }

      _ ->
        mob.position
    end
  end

  defp jitter(radius), do: :rand.uniform(radius * 2 + 1) - radius - 1
end
