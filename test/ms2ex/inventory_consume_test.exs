defmodule Ms2ex.Context.InventoryTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Context
  alias Ms2ex.Schema

  setup do
    stub_metadata(%{
      "item:30000122" => %{
        limit: %{level: 0, gender: 0, job_recommends: [], transfer_type: 0},
        property: %{type: 3, ride: 0, tradable_count: 0, stack_limit: 999},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    account = Repo.insert!(%Schema.Account{username: "pudding_test", password_hash: "x"})

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "PuddingTester",
        job: :knight,
        map_id: 1,
        skin_color: {}
      })

    %{character: character}
  end

  test "consuming an amount spans stacks and deletes emptied ones", %{character: character} do
    {:ok, {:create, first}} = Context.Inventory.add_item(character, pudding(1))
    {:ok, {:create, second}} = Context.Inventory.add_item(character, pudding(2))

    {:ok, results} = Context.Inventory.consume_item_amount(character, 30_000_122, 2)

    assert [{:delete, deleted}, {:update, updated}] = results
    assert deleted.id == first.id
    assert updated.id == second.id
    assert updated.amount == 1

    refute Context.Inventory.get(character, first.id)
    assert Context.Inventory.get(character, second.id).amount == 1
  end

  test "consuming more than owned fails without changing stacks", %{character: character} do
    {:ok, {:create, item}} = Context.Inventory.add_item(character, pudding(1))

    assert {:error, :insufficient_amount} =
             Context.Inventory.consume_item_amount(character, 30_000_122, 2)

    assert Context.Inventory.get(character, item.id).amount == 1
  end

  test "batch consumption spans pairs sharing stacks and skips uncovered ones", %{
    character: character
  } do
    {:ok, {:create, first}} = Context.Inventory.add_item(character, pudding(2))

    consumables = [
      %{item_id: 30_000_122, amount: 1},
      %{item_id: 30_000_122, amount: 5},
      %{item_id: 30_000_122, amount: 1}
    ]

    {:ok, results} = Context.Inventory.consume_item_amounts(character, consumables)

    # the 2-stack covers the first pair (1 left) and the third pair (emptied);
    # the middle pair is skipped as uncovered
    assert [{:update, updated}, {:delete, deleted}] = results
    assert updated.id == first.id
    assert updated.amount == 1
    assert deleted.id == first.id

    refute Context.Inventory.get(character, first.id)
  end

  defp pudding(amount) do
    Context.Items.init(30_000_122, %{amount: amount, rarity: 1})
  end
end
