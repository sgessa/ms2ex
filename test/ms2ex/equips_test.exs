defmodule Ms2ex.EquipsTest do
  # the transitions spawn character processes that read the stubbed metadata
  # from another process, so the stubs must be visible globally
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      # BindOnEquip staff metadata (item 15260310 from the dev seed)
      "item:15260310" => %{
        limit: %{
          level: 70,
          gender: 2,
          job_recommends: [30],
          transfer_type: 3,
          trade_max_rarity: 4
        },
        property: %{type: 1, ride: 0, tradable_count: 1},
        slot_names: [5, 4],
        option: %{constant_id: 15_260_310, pick_id: 0, static_id: 0, random_id: 0}
      },
      # generic items used by the allocation / preference tests
      "item:4001" => item_meta([11]),
      "item:4002" => item_meta([11])
    })

    :ok
  end

  test "equipping a BindOnEquip item persists the bound state" do
    account = Repo.insert!(%Schema.Account{username: "equip_test", password_hash: "x"})

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "EquipTester",
        job: :knight,
        map_id: 1,
        skin_color: {}
      })

    start_inventory(character)

    staff = Context.Items.init(15_260_310, %{rarity: 5, amount: 1})
    {:ok, {:create, item}} = Managers.Inventory.add_item(character, staff)
    assert item.is_bound == false

    {:ok, equipped} = Managers.Inventory.equip(item |> Context.Items.load_metadata(), :RH)
    assert equipped.is_bound == true

    reloaded = Repo.get(Schema.Item, item.id)
    assert reloaded.is_bound == true
    assert reloaded.remaining_trades == 0
    assert reloaded.location == :equipment
  end

  # ---- slot allocation ----

  test "slot allocation is bounded by the tab's slot count" do
    character = insert_character()
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :gear, slots: 3})

    insert_gear_item(character.id, 0)
    insert_gear_item(character.id, 1)

    start_inventory(character)

    assert Managers.Inventory.find_first_available_slot(character.id, :gear) == 2

    add_inventory_item(character, 4002)

    assert Managers.Inventory.find_first_available_slot(character.id, :gear) ==
             {:error, :full_inventory}

    assert Managers.Inventory.free_slot_count(character.id, :gear) == 0

    # expanding the tab raises the bound
    Managers.Inventory.expand_tab(character, :gear)

    assert Managers.Inventory.find_first_available_slot(character.id, :gear) == 3
    assert Managers.Inventory.free_slot_count(character.id, :gear) == 6
  end

  test "unequip prefers a free slot and falls back when it is taken" do
    character = insert_character()
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :gear, slots: 3})

    insert_gear_item(character.id, 0)

    start_inventory(character)

    equipped = equip_item(character, 4001, :RH)
    {:ok, item} = Managers.Inventory.move_to_inventory(equipped, 0)
    # slot 0 is occupied, so the item lands in the first open slot
    assert item.inventory_slot == 1

    equipped = equip_item(character, 4001, :RH)
    {:ok, item} = Managers.Inventory.move_to_inventory(equipped, 2)
    # slot 2 is free, so the preference is honored
    assert item.inventory_slot == 2
  end

  # ---- equip transitions (character manager) ----

  test "equipping a two-slot item unequips everything it covers" do
    stub_metadata(%{
      "item:3001" => item_meta([5, 4], %{level: 10}),
      "item:3002" => item_meta([5], %{level: 10}),
      "item:3003" => item_meta([19], %{level: 10})
    })

    character = insert_character()

    start_inventory(character)

    staff = add_inventory_item(character, 3001)
    sword = equip_item(character, 3002, :RH)
    shield = equip_item(character, 3003, :LH)

    character = %{character | equips: Managers.Inventory.list_equips(character)}
    start_character(character)

    assert {:ok, character} = Managers.Character.call(character, {:equip_item, staff.id, "RH"})

    # the staff covers both hands, so the sword and the shield return to the
    # inventory and only the staff stays equipped
    assert equips(character) == [:RH]

    assert Repo.reload!(sword).location == :inventory
    assert Repo.reload!(shield).location == :inventory

    staff_row = Repo.reload!(staff)
    assert staff_row.location == :equipment
    assert staff_row.equip_slot == :RH

    reloaded = Managers.Character.call(character.id, :lookup) |> elem(1)
    assert equips(reloaded) == [:RH]
  end

  test "equipping pants over a suit keeps the suit equipped" do
    stub_metadata(%{
      "item:3101" => item_meta([8, 9], %{level: 10, is_skin: true}),
      "item:3102" => item_meta([9], %{level: 10, is_skin: true})
    })

    character = insert_character()
    start_inventory(character)

    suit = equip_item(character, 3101, :CL)
    pants = add_inventory_item(character, 3102)

    character = %{character | equips: Managers.Inventory.list_equips(character)}
    start_character(character)

    assert {:ok, character} = Managers.Character.call(character, {:equip_item, pants.id, "PA"})

    # the suit only occupies the clothing slot, so the pants join it instead
    # of displacing it
    assert character |> equips() |> Enum.sort() == [:CL, :PA]

    assert Repo.reload!(suit).location == :equipment
    assert Repo.reload!(pants).location == :equipment

    reloaded = Managers.Character.call(character.id, :lookup) |> elem(1)
    assert reloaded |> equips() |> Enum.sort() == [:CL, :PA]
  end

  test "equipping fails for a slot the item does not occupy" do
    stub_metadata(%{"item:3101" => item_meta([8, 9], %{level: 10, is_skin: true})})

    character = insert_character()
    start_inventory(character)

    suit = add_inventory_item(character, 3101)

    character = %{character | equips: Managers.Inventory.list_equips(character)}
    start_character(character)

    # the suit occupies clothing first; the pants slot is not a valid target
    assert :error = Managers.Character.call(character, {:equip_item, suit.id, "PA"})

    assert Repo.reload!(suit).location == :inventory
    assert [] == equips(Managers.Character.call(character.id, :lookup) |> elem(1))
  end

  test "equipping fails for an item above the character's level" do
    stub_metadata(%{"item:3201" => item_meta([6], %{level: 999})})

    character = insert_character(level: 10)
    start_inventory(character)

    hat = add_inventory_item(character, 3201)

    character = %{character | equips: Managers.Inventory.list_equips(character)}
    start_character(character)

    assert :error = Managers.Character.call(character, {:equip_item, hat.id, "CP"})
    assert_received {:push, <<0x73::little-16, 4::8, 64::little-16, _::binary>>}

    assert Repo.reload!(hat).location == :inventory
  end

  test "equipping fails for an item with foreign job limits" do
    stub_metadata(%{"item:3202" => item_meta([5], %{level: 10, job_limits: [30]})})

    character = insert_character(job: :knight)
    start_inventory(character)

    blade = add_inventory_item(character, 3202)

    character = %{character | equips: Managers.Inventory.list_equips(character)}
    start_character(character)

    assert :error = Managers.Character.call(character, {:equip_item, blade.id, "RH"})
    assert Repo.reload!(blade).location == :inventory
  end

  test "unequipping discards cosmetic looks" do
    stub_metadata(%{"item:3301" => item_meta([1], %{level: 10})})

    character = insert_character()
    start_inventory(character)
    hair = equip_item(character, 3301, :HR)

    character = %{character | equips: Managers.Inventory.list_equips(character)}
    start_character(character)

    assert {:ok, character} = Managers.Character.call(character, {:unequip_item, hair.id})

    # the look cannot be worn again, so the item is gone entirely
    assert Repo.get(Schema.Item, hair.id) == nil
    assert [] == equips(character)
    assert [] == equips(Managers.Character.call(character.id, :lookup) |> elem(1))
  end

  # ---- helpers ----

  defp item_meta(slot_names, limit_overrides \\ %{}) do
    limit =
      Map.merge(
        %{
          level: 10,
          gender: 2,
          job_limits: [],
          job_recommends: [],
          transfer_type: 3,
          trade_max_rarity: 4
        },
        limit_overrides
      )

    %{
      limit: limit,
      property: %{
        type: 1,
        is_skin: Map.get(limit_overrides, :is_skin, false),
        ride: 0,
        tradable_count: 1
      },
      slot_names: slot_names,
      option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
    }
  end

  defp insert_character(overrides \\ []) do
    account =
      Repo.insert!(%Schema.Account{
        username: "equips_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "EqTest#{System.unique_integer([:positive])}",
        job: Keyword.get(overrides, :job, :knight),
        level: Keyword.get(overrides, :level, 60),
        map_id: 1,
        skin_color: {}
      })

    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    character = %{character | stats: stats, sender_session_pid: self()}
    Repo.preload(character, skill_tabs: :skills)
  end

  defp start_character(character) do
    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
    pid
  end

  defp add_inventory_item(character, item_id) do
    item = Context.Items.init(item_id, %{rarity: 1, amount: 1})
    {:ok, {:create, item}} = Managers.Inventory.add_item(character, item)
    item
  end

  defp equip_item(character, item_id, equip_slot) do
    item = add_inventory_item(character, item_id)
    {:ok, item} = Managers.Inventory.equip(item |> Context.Items.load_metadata(), equip_slot)
    item
  end

  defp start_inventory(character) do
    :ok = Managers.Inventory.start(character)

    on_exit(fn -> Managers.Inventory.stop(character.id) end)

    Ecto.Adapters.SQL.Sandbox.allow(
      Repo,
      self(),
      :erlang.whereis(:"inventories:#{character.id}")
    )
  end

  defp insert_gear_item(character_id, slot) do
    Repo.insert!(%Schema.Item{
      character_id: character_id,
      item_id: 4002,
      amount: 1,
      rarity: 1,
      location: :inventory,
      inventory_tab: :gear,
      inventory_slot: slot
    })
  end

  defp equips(character), do: Enum.map(character.equips, & &1.equip_slot)
end
