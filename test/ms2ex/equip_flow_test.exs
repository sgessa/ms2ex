defmodule Ms2ex.EquipFlowTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema

  @gear_a 6_000_001
  @gear_b 6_000_002

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "item:#{@gear_a}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [11],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:#{@gear_b}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [11],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    character = insert_character()

    %{character: character}
  end

  test "equip then replace keeps bag and equips coherent", %{character: character} do
    start_managers(character)

    a = add_item(character, @gear_a)
    b = add_item(character, @gear_b)

    # equip A into its primary slot (7 = SH)
    assert {:ok, char} = Managers.Character.call(character, {:equip_item, a.id, "SH"})
    assert equip_summary(char) == [@gear_a]

    # equip B into the same slot: A must return to the bag
    assert {:ok, char} = Managers.Character.call(character, {:equip_item, b.id, "SH"})
    assert equip_summary(char) == [@gear_b]

    # the bag slot of the equipped item frees up before the displaced item
    # is added, otherwise the client drops the add
    b_uid = b.id
    a_uid = a.id

    assert_received {:push, <<0x21::little-16, 0x01, ^b_uid::little-32, _::binary>>}

    assert_received {:push,
                     <<0x21::little-16, 0x00, @gear_a::little-32, ^a_uid::little-32,
                       _slot::little-16, _rest::binary>>}

    a_row = Repo.reload!(a)
    assert a_row.location == :inventory
    assert a_row.inventory_slot != nil

    b_row = Repo.reload!(b)
    assert b_row.location == :equipment

    # no duplicate uids in the manager's bag view
    bag = Managers.Inventory.list_tab_items(character.id, :gear)
    assert Enum.map(bag, & &1.id) == [a.id]

    # unequip B: back to the bag
    assert {:ok, char} = Managers.Character.call(character, {:unequip_item, b.id})
    assert equip_summary(char) == []
    assert Enum.count(Managers.Inventory.list_tab_items(character.id, :gear)) == 2
    assert Repo.reload!(b).location == :inventory
  end

  defp insert_character do
    account =
      Repo.insert!(%Schema.Account{
        username: "flow_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Flow#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    character = %{character | stats: stats, sender_session_pid: self()}
    Repo.preload(character, skill_tabs: :skills)
  end

  defp start_managers(character) do
    :ok = Managers.Inventory.start(character)
    inv_pid = :erlang.whereis(:"inventories:#{character.id}")

    # prime the cached equip list the same way login does
    character = %{character | equips: Managers.Inventory.list_equips(character)}
    {:ok, char_pid} = Managers.Character.start(character)

    on_exit(fn ->
      if Process.alive?(char_pid), do: GenServer.stop(char_pid)
      Managers.Inventory.stop(character.id)
    end)

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), char_pid)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), inv_pid)
  end

  defp add_item(character, item_id) do
    item = Context.Items.init(item_id, %{rarity: 4, amount: 1})
    {:ok, {:create, item}} = Managers.Inventory.add_item(character, item)
    item
  end

  defp equip_summary(character), do: Enum.map(character.equips, & &1.item_id)
end
