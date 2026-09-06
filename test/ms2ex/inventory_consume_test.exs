defmodule Ms2ex.Context.InventoryTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Context
  alias Ms2ex.Managers.Inventory

  setup do
    stub_metadata(%{
      "item:30000122" => %{
        limit: %{level: 0, gender: 0, job_recommends: [], transfer_type: 0},
        property: %{type: 3, ride: 0, tradable_count: 0, stack_limit: 999},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    state = %{character_id: 1, items: [], tabs: [], lock_staging: []}

    %{state: state, pudding: &pudding/1}
  end

  test "consuming an amount spans stacks and deletes emptied ones", %{state: state} do
    {{:ok, {:create, first}}, state} = Inventory.add_to_state(state, pudding(1))
    {{:ok, {:create, second}}, state} = Inventory.add_to_state(state, pudding(2))

    {results, state} =
      Inventory.consume_amounts_from_state(state, [%{item_id: 30_000_122, amount: 2}])

    assert [{:delete, deleted}, {:update, updated}] = results
    assert deleted.id == first.id
    assert updated.id == second.id
    assert updated.amount == 1

    refute Inventory.get_from_state(state, first.id)
    assert Inventory.get_from_state(state, second.id).amount == 1
  end

  test "consuming more than owned fails without changing stacks", %{state: state} do
    {{:ok, {:create, item}}, state} = Inventory.add_to_state(state, pudding(1))

    {results, _state} =
      Inventory.consume_amounts_from_state(state, [%{item_id: 30_000_122, amount: 2}])

    assert results == []
    assert Inventory.get_from_state(state, item.id).amount == 1
  end

  test "batch consumption spans pairs sharing stacks and skips uncovered ones", %{state: state} do
    {{:ok, {:create, first}}, state} = Inventory.add_to_state(state, pudding(2))

    consumables = [
      %{item_id: 30_000_122, amount: 1},
      %{item_id: 30_000_122, amount: 5},
      %{item_id: 30_000_122, amount: 1}
    ]

    {results, state} = Inventory.consume_amounts_from_state(state, consumables)

    # the 2-stack covers the first pair (1 left) and the third pair (emptied);
    # the middle pair is skipped as uncovered
    assert [{:update, updated}, {:delete, deleted}] = results
    assert updated.id == first.id
    assert updated.amount == 1
    assert deleted.id == first.id

    refute Inventory.get_from_state(state, first.id)
  end

  defp pudding(amount) do
    Context.Items.init(30_000_122, %{amount: amount, rarity: 1})
  end
end
