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
        Managers.Character.increase_stat(character, :sp, item.amount)

      Context.Items.stamina?(item) ->
        Managers.Character.increase_stat(character, :sta, item.amount)

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
    item = %{
      item
      | position: character.position,
        object_id: state.counter,
        source_object_id: character.object_id
    }

    Context.Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, state.counter, item)
    %{state | counter: state.counter + 1, items: items}
  end

  def add_mob_drop(mob, item, state) do
    item = %{
      item
      | position: mob.position,
        object_id: state.counter,
        lock_character_id: mob.last_attacker.id,
        mob_drop?: true,
        source_object_id: mob.object_id,
        target_object_id: mob.last_attacker.object_id
    }

    Context.Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, state.counter, item)
    %{state | counter: state.counter + 1, items: items}
  end
end
