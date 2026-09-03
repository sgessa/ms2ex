defmodule Ms2ex.InventoryManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  @potion_id 5_000_001
  @gear_id 5_000_002

  setup do
    stub_metadata(%{
      "item:#{@potion_id}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 0, subtype: 2},
        slot_names: [],
        stack_limit: 10,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:#{@gear_id}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [5],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:6000001" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [11],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:6000002" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [11],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    character = insert_character()

    # tabs must exist before the manager loads its state
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :consumable, slots: 84})
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :gear, slots: 3})

    start_inventory(character)

    %{character: character}
  end

  test "slot allocation is served from the owned item list", %{character: character} do
    add_item(character, @gear_id, 1)
    add_item(character, @gear_id, 1)
    assert Context.Inventory.find_first_available_slot(character.id, :gear) == 2

    add_item(character, @gear_id, 1)

    assert Context.Inventory.find_first_available_slot(character.id, :gear) ==
             {:error, :full_inventory}

    assert Context.Inventory.free_slot_count(character.id, :gear) == 0

    assert Context.Inventory.expand_tab(character, :gear).slots == 9
    assert Context.Inventory.free_slot_count(character.id, :gear) == 6
  end

  test "stackable items merge onto existing stacks and write through", %{character: character} do
    add_item(character, @potion_id, 4)
    add_item(character, @potion_id, 6)

    # the second stack exactly fills the first, so no second row is created
    assert Enum.count(Context.Inventory.list_tab_items(character.id, :consumable)) == 1

    add_item(character, @potion_id, 3)

    stacks = Context.Inventory.list_tab_items(character.id, :consumable)
    assert Enum.map(stacks, & &1.amount) == [10, 3]
  end

  test "consume writes through and deletes emptied stacks", %{character: character} do
    {:ok, {:create, stack}} = add_item(character, @potion_id, 5)

    {:update, updated} = Context.Inventory.consume(stack, 2)
    assert updated.amount == 3
    assert Repo.reload!(stack).amount == 3

    {:delete, _deleted} = Context.Inventory.consume(updated, 3)
    assert Repo.get(Schema.Item, stack.id) == nil
  end

  test "consuming across stacks skips pairs that cannot be covered", %{character: character} do
    add_item(character, @potion_id, 6)
    add_item(character, @potion_id, 6)

    # the second add overflows the first stack: 10 + 2 across two stacks
    stacks = Context.Inventory.list_tab_items(character.id, :consumable)
    assert Enum.map(stacks, & &1.amount) == [10, 2]

    {:ok, results} =
      Context.Inventory.consume_item_amounts(character, [
        %{item_id: @potion_id, amount: 11},
        %{item_id: @potion_id, amount: 50}
      ])

    # 11 span both stacks (two stack writes), the impossible pair is skipped
    assert Enum.count(results) == 2

    remaining = Context.Inventory.list_tab_items(character.id, :consumable)
    assert Enum.sum(Enum.map(remaining, & &1.amount)) == 1
  end

  test "sort_tab reassigns slots by item id", %{character: character} do
    # inserted in reverse so the sort has to move both rows
    {:ok, {:create, b}} = add_item(character, 6_000_002, 1)
    {:ok, {:create, a}} = add_item(character, 6_000_001, 1)

    assert {:ok, sorted} = Context.Inventory.sort_tab(character, :gear)

    assert Enum.map(sorted, & &1.item_id) == [6_000_001, 6_000_002]
    assert Enum.map(sorted, & &1.inventory_slot) == [0, 1]

    assert Repo.reload!(a).inventory_slot == 0
    assert Repo.reload!(b).inventory_slot == 1
  end

  test "item locks stage and commit is_locked", %{character: character} do
    {:ok, {:create, a}} = add_item(character, @gear_id, 1)
    {:ok, {:create, b}} = add_item(character, @gear_id, 1)

    assert {:ok, 0} = Managers.Inventory.call(character.id, {:lock_stage, a.id})
    assert {:ok, 1} = Managers.Inventory.call(character.id, {:lock_stage, b.id})

    # unstaging removes the item from the staging list
    assert :ok = Managers.Inventory.call(character.id, {:lock_unstage, a.id})

    {:ok, [updated]} = Managers.Inventory.call(character.id, {:lock_commit, false})
    assert updated.id == b.id
    assert updated.is_locked
    assert Repo.reload!(b).is_locked
    refute Repo.reload!(a).is_locked

    # the staging list is cleared after a commit
    assert {:ok, 0} = Managers.Inventory.call(character.id, {:lock_stage, b.id})

    {:ok, [unlocked]} = Managers.Inventory.call(character.id, {:lock_commit, true})
    refute unlocked.is_locked
    refute Repo.reload!(b).is_locked

    # the unlock window is stamped on the item and survives reloads and sorts
    assert unlocked.unlocks_at != nil
    assert Repo.reload!(b).unlocks_at != nil

    {:ok, sorted} = Context.Inventory.sort_tab(character, :gear)
    sorted_b = Enum.find(sorted, &(&1.id == b.id))
    assert sorted_b.unlocks_at == unlocked.unlocks_at
  end

  test "moving an item to equipment keeps the manager and rows coherent", %{
    character: character
  } do
    {:ok, {:create, stack}} = add_item(character, @gear_id, 1)

    {:ok, equipped} = Context.Inventory.update_item(stack, %{location: :equipment})
    assert equipped.location == :equipment

    equips = Context.Equips.list(character)
    assert Enum.map(equips, & &1.id) == [stack.id]

    assert Repo.reload!(stack).location == :equipment
  end

  defp insert_character do
    account =
      Repo.insert!(%Schema.Account{
        username: "inv_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Inv#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    %{character | stats: stats, sender_session_pid: self()}
  end

  defp start_inventory(character) do
    :ok = Managers.Inventory.start(character)
    on_exit(fn -> Managers.Inventory.stop(character.id) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), process(character.id))
  end

  defp process(character_id), do: :erlang.whereis(:"inventories:#{character_id}")

  defp add_item(character, item_id, amount) do
    item = Context.Items.init(item_id, %{rarity: 1, amount: amount})
    Context.Inventory.add_item(character, item)
  end
end
