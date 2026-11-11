defmodule Ms2ex.PetBagFlowTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @potion 20_000_013
  @bag_owner 999_001

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "item:#{@potion}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 2},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0},
        stack_limit: 100
      }
    })

    character = insert_character()
    :ok = Managers.Inventory.start(character)

    inv_pid = :erlang.whereis(:"inventories:#{character.id}")

    on_exit(fn -> Managers.Inventory.stop(character.id) end)

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), inv_pid)

    %{character: character}
  end

  test "a deposit that fits a bag stack updates the stack only", %{character: character} do
    first = add_item(character, 90)
    second = add_item(character, 50)

    # the inventory merges the two adds: one 100 stack and one 40 stack;
    # 90 of the 100 stack seeds the bag
    assert {:ok, %{source: {:update, source}, bag: {:create, seeded}}} =
             Managers.Inventory.pet_bag_add(character.id, @bag_owner, first.id, 0, 90, 4)

    assert seeded.amount == 90
    assert source.amount == 10

    # 10 of the remaining 40 absorbs into the seeded stack
    assert {:ok, %{source: {:update, source}, bag: {:update, filled}}} =
             Managers.Inventory.pet_bag_add(character.id, @bag_owner, second.id, 1, 10, 4)

    assert filled.id == seeded.id
    assert filled.amount == 100
    assert source.amount == 30
    assert bag_rows(character.id) == [{0, 100}]
  end

  test "a deposit overflowing a bag stack fills it and spills into the slot", %{
    character: character
  } do
    stack = add_item(character, 90)

    # the first deposit empties the inventory stack into the bag
    assert {:ok, %{source: {:delete, _}, bag: {:create, seeded}}} =
             Managers.Inventory.pet_bag_add(character.id, @bag_owner, stack.id, 0, 90, 4)

    assert seeded.amount == 90

    # a fresh inventory stack: 50 more goes 10 into the seeded stack and
    # 40 into a new bag row
    refill = add_item(character, 50)

    assert {:ok,
            %{
              source: {:delete, _},
              bag: {:update_and_create, {filled, _absorbed}, created}
            }} =
             Managers.Inventory.pet_bag_add(character.id, @bag_owner, refill.id, 1, 50, 4)

    assert filled.id == seeded.id
    assert filled.amount == 100
    assert created.amount == 40
    assert created.location == :pet
    assert created.owner_item_id == @bag_owner
    assert created.inventory_slot == 1
    assert bag_rows(character.id) |> Enum.sort() == [{0, 100}, {1, 40}]
  end

  test "a deposit over a full bag fails and leaves the inventory untouched", %{
    character: character
  } do
    stack = add_item(character, 90)

    assert {:ok, _} =
             Managers.Inventory.pet_bag_add(character.id, @bag_owner, stack.id, 0, 90, 1)

    refill = add_item(character, 50)
    uid = refill.id

    assert {:error, :bag_full} =
             Managers.Inventory.pet_bag_add(character.id, @bag_owner, uid, 1, 50, 1)

    row = Repo.reload!(refill)
    assert row.amount == 50
    assert row.location == :inventory
    assert bag_rows(character.id) == [{0, 90}]
  end

  defp insert_character do
    account =
      Repo.insert!(%Schema.Account{
        username: "bag_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    Repo.insert!(%Schema.Character{
      account_id: account.id,
      name: "Bag#{System.unique_integer([:positive])}",
      job: :knight,
      level: 10,
      map_id: 1,
      skin_color: {}
    })
  end

  defp add_item(character, amount) do
    item = Context.Items.init(@potion, %{rarity: 1, amount: amount})
    {:ok, result} = Managers.Inventory.add_item(character, item)

    # merged adds return the split pair; the created stack is the useful one
    case result do
      {:create, item} -> item
      {:update_and_create, {_updated, _moved}, created} -> created
      {:update, item} -> item
    end
  end

  defp bag_rows(character_id) do
    Managers.Inventory.pet_bag_items(character_id, @bag_owner)
    |> Enum.map(&{&1.inventory_slot, &1.amount})
  end
end
