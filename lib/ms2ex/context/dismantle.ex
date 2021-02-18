defmodule Ms2ex.Dismantle do
  alias Ms2ex.{Inventory, Metadata}

  @max_slots 100
  def max_slots(), do: @max_slots

  def add(%{slots: slots} = inventory, slot, uid, amount) when slot >= 0 do
    if Map.has_key?(slots, slot) do
      append(inventory, uid, amount)
    else
      slots = Map.put(slots, slot, {uid, amount})
      {slot, %{inventory | slots: slots}}
    end
  end

  def add(inventory, -1, uid, amount) do
    append(inventory, uid, amount)
  end

  def append(%{slots: slots} = inventory, uid, amount) do
    free_slot = Enum.find(0..@max_slots, &(!Map.has_key?(slots, &1)))
    slots = Map.put(slots, free_slot, {uid, amount})
    {free_slot, %{inventory | slots: slots}}
  end

  def remove(%{slots: slots} = inventory, slot) do
    slots = Map.delete(slots, slot)
    %{inventory | slots: slots}
  end

  def update_rewards(character, inventory) do
    rewards =
      Enum.reduce(inventory.slots, %{}, fn {_slot, {item_uid, amount}}, total_rewards ->
        item = character |> Inventory.get(item_uid) |> Metadata.Items.load()
        rewards = Map.get(item.metadata, :dismantle_rewards, [])

        Enum.reduce(rewards, total_rewards, fn reward, total_rewards ->
          if reward.item_id != 0 do
            total_amount = Map.get(total_rewards, reward.item_id, 0)
            total_amount = total_amount + reward.amount * amount
            Map.put(total_rewards, reward.item_id, total_amount)
          else
            total_rewards
          end
        end)
      end)

    %{inventory | rewards: rewards}
  end
end
