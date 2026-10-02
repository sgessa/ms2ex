defmodule Ms2ex.StorageManagerTest do
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
        limit: %{level: 1, transfer_type: 3, shop_sell: true},
        property: %{type: 0, subtype: 2},
        slot_names: [],
        stack_limit: 10,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:#{@gear_id}" => %{
        limit: %{level: 1, transfer_type: 3, shop_sell: true},
        property: %{type: 1, subtype: 0},
        slot_names: [],
        stack_limit: 1,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "table:server.constants.xml" => %{
        store_expand_max_slot_count: 42
      }
    })

    account =
      Repo.insert!(%Schema.Account{
        username: "storage_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Store#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    character = %{character | stats: stats, sender_session_pid: self()}

    # tabs must exist before the inventory manager loads its state
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :consumable, slots: 84})
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :gear, slots: 4})

    Repo.insert!(%Schema.Wallet{character_id: character.id, mesos: 10_000})
    Repo.insert!(%Schema.AccountWallet{account_id: account.id, merets: 1_000})

    start_inventory(character)
    start_wallet(character)

    %{account: account, character: character}
  end

  test "deposit stores the item on the account and removes it from the inventory", %{
    character: character
  } do
    {:ok, {:create, item}} = add_item(character, @gear_id, 1)

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, item.id, 0, 1}, from(), state)

    assert Managers.Inventory.list_tab_items(character.id, :gear) == []

    [stored] = Context.Storages.list_items(character.account_id)
    assert stored.item_id == @gear_id
    assert stored.account_id == character.account_id
    assert stored.character_id == nil
    assert stored.inventory_slot == 0

    assert state.items[stored.id].item_id == @gear_id

    assert_received {:push, _consume}
    assert_received {:push, _storage_add}
  end

  test "deposit stacks onto existing storage stacks", %{character: character} do
    {:ok, {:create, first}} = add_item(character, @potion_id, 6)

    # 5 more split off into their own stack (limit 10)
    second =
      case add_item(character, @potion_id, 5) do
        {:ok, {:create, item}} -> item
        {:ok, {:update_and_create, {_updated, _amount}, created}} -> created
      end

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, first.id, 0, 6}, from(), state)

    {:reply, :ok, _state} =
      Managers.Storage.handle_call({:deposit, character, second.id, 0, 1}, from(), state)

    # the second deposit stacks onto the first (6 + 1 of limit 10)
    stored = Context.Storages.list_items(character.account_id)
    assert Enum.map(stored, & &1.amount) == [7]

    assert Enum.map(stored, & &1.item_id) == [@potion_id]

    assert_received {:push, _consume}
    assert_received {:push, _storage_add}
    assert_received {:push, _consume}
    assert_received {:push, _storage_update}
  end

  test "withdraw returns the item to the inventory", %{character: character} do
    {:ok, {:create, item}} = add_item(character, @gear_id, 1)

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, item.id, 0, 1}, from(), state)

    [stored] = Map.values(state.items)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:withdraw, character, stored.id, 3, 1}, from(), state)

    assert Context.Storages.list_items(character.account_id) == []
    assert state.items == %{}

    items = Managers.Inventory.list_tab_items(character.id, :gear)
    assert Enum.map(items, & &1.inventory_slot) == [3]

    assert_received {:push, _consume}
    assert_received {:push, _storage_add}
    assert_received {:push, _storage_remove}
    assert_received {:push, _inventory_add}
  end

  test "withdraw of part of a stack updates the stored amount", %{character: character} do
    {:ok, {:create, item}} = add_item(character, @potion_id, 6)

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, item.id, 0, 6}, from(), state)

    [stored] = Map.values(state.items)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:withdraw, character, stored.id, 5, 2}, from(), state)

    [stored] = Context.Storages.list_items(character.account_id)
    assert stored.amount == 4
    assert state.items[stored.id].amount == 4

    assert Enum.map(Managers.Inventory.list_tab_items(character.id, :consumable), & &1.amount) ==
             [
               2
             ]
  end

  test "move swaps two occupied slots", %{character: character} do
    {:ok, {:create, gear}} = add_item(character, @gear_id, 1)
    {:ok, {:create, potion}} = add_item(character, @potion_id, 1)

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, gear.id, 0, 1}, from(), state)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, potion.id, 5, 1}, from(), state)

    [gear_stored, _potion_stored] = Context.Storages.list_items(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:move, character, gear_stored.id, 5}, from(), state)

    slots_by_item =
      state.items |> Map.values() |> Map.new(&{&1.item_id, &1.inventory_slot})

    assert slots_by_item == %{@gear_id => 5, @potion_id => 0}

    assert_received {:push, _storage_move}
  end

  test "depositing more mesos than the wallet holds is rejected", %{character: character} do
    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit_mesos, character, 20_000}, from(), state)

    assert state.mesos == 0
    assert wallet(character).mesos == 10_000
    assert Repo.reload!(state.storage).mesos == 0

    # only the storage error arrives: the failed debit pushes nothing
    assert_received {:push, _storage_error}
    refute_received {:push, _packet}
  end

  test "deposit and withdraw mesos move the wallet balance", %{character: character} do
    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit_mesos, character, 2_500}, from(), state)

    assert state.mesos == 2_500
    assert wallet(character).mesos == 7_500
    assert Repo.reload!(state.storage).mesos == 2_500

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:withdraw_mesos, character, 1_000}, from(), state)

    assert state.mesos == 1_500
    assert wallet(character).mesos == 8_500

    assert_received {:push, _wallet}
    assert_received {:push, _storage_mesos}
    assert_received {:push, _wallet}
    assert_received {:push, _storage_mesos}
  end

  test "expand buys one row with merets up to the cap", %{character: character} do
    price = Ms2ex.Constants.get(:storage_expand_price1_row)
    state = init_storage(character.account_id)

    # cap is stubbed at 42: 36 + 6 fits, 36 + 12 does not
    {:reply, :ok, state} = Managers.Storage.handle_call({:expand, character}, from(), state)

    assert state.expand == 6
    assert Repo.reload!(state.storage).expand == 6

    assert Repo.get_by!(Schema.AccountWallet, account_id: character.account_id).merets ==
             1_000 - price

    {:reply, :ok, state} = Managers.Storage.handle_call({:expand, character}, from(), state)

    assert state.expand == 6

    assert Repo.get_by!(Schema.AccountWallet, account_id: character.account_id).merets ==
             1_000 - price

    assert_received {:push, _debit}
    assert_received {:push, _reset}
    assert_received {:push, _slots_expanded}
    assert_received {:push, _error}
  end

  test "delete destroys the stored item", %{character: character} do
    {:ok, {:create, item}} = add_item(character, @gear_id, 1)

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, item.id, 0, 1}, from(), state)

    [stored] = Map.values(state.items)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:delete, character, stored.id}, from(), state)

    assert state.items == %{}
    assert Context.Storages.list_items(character.account_id) == []
  end

  test "the handler parses deposit requests (leading zero + uid)", %{character: character} do
    {:ok, _} = Managers.Character.start(character)
    {:ok, {:create, item}} = add_item(character, @potion_id, 3)

    session = %{character_id: character.id, type: :channel}

    # load, exactly like the client
    :ok = Ms2ex.GameHandlers.RequestItemStorage.handle(<<0x0C, 0::little-64>>, session)

    # deposit: command 0, zero long, uid long, slot short, amount int
    packet = <<0x00, 0::little-64, item.id::little-64, 0::little-16, 3::little-32>>
    :ok = Ms2ex.GameHandlers.RequestItemStorage.handle(packet, session)

    stored = Context.Storages.list_items(character.account_id)
    assert Enum.map(stored, &{&1.item_id, &1.amount}) == [{@potion_id, 3}]

    # the storage add + the inventory consume reached the client
    assert_received {:push, _storage_add}
    assert_received {:push, _consume}
  end

  test "sort compacts the rows and re-sends the window", %{character: character} do
    {:ok, {:create, potion}} = add_item(character, @potion_id, 1)
    {:ok, {:create, gear}} = add_item(character, @gear_id, 1)

    state = init_storage(character.account_id)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, potion.id, 5, 1}, from(), state)

    {:reply, :ok, state} =
      Managers.Storage.handle_call({:deposit, character, gear.id, 9, 1}, from(), state)

    {:reply, :ok, state} = Managers.Storage.handle_call({:sort, character}, from(), state)

    slots_by_item =
      state.items |> Map.values() |> Map.new(&{&1.item_id, &1.inventory_slot})

    # ordered by item id: the potion (5_000_001) takes slot 0
    assert slots_by_item == %{@potion_id => 0, @gear_id => 1}

    assert Enum.map(Context.Storages.list_items(character.account_id), & &1.inventory_slot) == [
             0,
             1
           ]

    assert_received {:push, _reset}
    assert_received {:push, _slots_expanded}
    assert_received {:push, _update_mesos}
    assert_received {:push, _slots_used}
    assert_received {:push, _load}
  end

  defp init_storage(account_id) do
    {:ok, state} = Managers.Storage.init(account_id)
    state
  end

  defp from, do: {self(), make_ref()}

  defp wallet(character), do: Repo.get_by!(Schema.Wallet, character_id: character.id)

  defp start_wallet(character) do
    :ok = Managers.Wallet.start(character)
    on_exit(fn -> Managers.Wallet.stop(character.id) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), :erlang.whereis(:"wallets:#{character.id}"))
  end

  defp start_inventory(character) do
    :ok = Managers.Inventory.start(character)
    on_exit(fn -> Managers.Inventory.stop(character.id) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), inventory_process(character.id))
  end

  defp inventory_process(character_id), do: :erlang.whereis(:"inventories:#{character_id}")

  defp add_item(character, item_id, amount) do
    item = Context.Items.init(item_id, %{rarity: 1, amount: amount})
    Managers.Inventory.add_item(character, item)
  end
end
