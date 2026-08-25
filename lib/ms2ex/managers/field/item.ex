defmodule Ms2ex.Managers.Field.Item do
  import Ms2ex.Net.SenderSession, only: [push: 2]

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  def pickup_item(character, item, state) do
    cond do
      Context.Items.mesos?(item) ->
        Context.Wallets.update(character, :mesos, item.amount)

      Context.Items.valor_token?(item) ->
        Context.Wallets.update(character, :valor_tokens, item.amount)

      Context.Items.merets?(item) ->
        Context.Wallets.update(character, :merets, item.amount)

      Context.Items.rue?(item) ->
        Context.Wallets.update(character, :rues, item.amount)

      Context.Items.havi_fruit?(item) ->
        Context.Wallets.update(character, :havi_fruits, item.amount)

      Context.Items.sp?(item) ->
        Managers.Character.cast(character, {:increase_stat, :spirit, item.amount})

      Context.Items.stamina?(item) ->
        Managers.Character.cast(character, {:increase_stat, :stamina, item.amount})

      true ->
        item = Context.Items.load_metadata(item)

        with {:ok, result} <- Context.Inventory.add_item(character, item) do
          {_status, item} = result
          push(character, Packets.InventoryItem.add_item(result))
          push(character, Packets.InventoryItem.mark_item_new(item))
        end
    end

    Context.Field.broadcast(state.topic, Packets.FieldPickupItem.bytes(character, item))
    Context.Field.broadcast(state.topic, Packets.FieldRemoveItem.bytes(item.object_id))

    items = Map.delete(state.items, item.object_id)
    %{state | items: items}
  end

  def drop_item(character, item, state) do
    {object_id, state} = Managers.Field.next_local_id(state)

    item = %{
      item
      | position: character.position,
        object_id: object_id,
        source_object_id: character.object_id
    }

    Context.Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, object_id, item)
    %{state | items: items}
  end

  def add_mob_drop(mob, item, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    receiver = mob.first_attacker || mob.last_attacker

    item = %{
      item
      | position: drop_position(mob),
        object_id: object_id,
        lock_character_id: locked_receiver_id(mob, receiver),
        mob_drop?: true,
        source_object_id: mob.object_id,
        target_object_id: target_object_id(mob, receiver)
    }

    Context.Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, object_id, item)
    %{state | items: items}
  end

  # boss drops stay unlocked so anyone can pick them up
  defp locked_receiver_id(%{npc: %{boss?: true}}, _receiver), do: 0
  defp locked_receiver_id(_mob, receiver), do: receiver.id

  defp target_object_id(%{npc: %{boss?: true}}, _receiver), do: 0
  defp target_object_id(_mob, receiver), do: receiver.object_id

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
