defmodule Ms2ex.ShopManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  @shop_id 106
  @npc_id 11_000_004
  @potion_id 5_000_001
  @potion_entry_id 1
  @gear_id 5_000_002
  @gear_entry_id 2

  setup do
    stub_metadata(%{
      "item:#{@potion_id}" => %{
        limit: %{level: 1, transfer_type: 3, shop_sell: true},
        property: %{
          type: 0,
          subtype: 2,
          sell_prices: [100, 200, 300, 400, 500, 600],
          custom_sell_prices: []
        },
        slot_names: [],
        stack_limit: 10,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "item:#{@gear_id}" => %{
        limit: %{level: 1, transfer_type: 3, shop_sell: true},
        property: %{
          type: 1,
          subtype: 0,
          sell_prices: [10, 20, 30, 40, 50, 60],
          custom_sell_prices: []
        },
        slot_names: [],
        stack_limit: 1,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "table:server.shop.xml" => %{
        @shop_id => %{
          id: @shop_id,
          category_id: 4,
          name: "shopetc",
          frame_type: 0,
          display_only_usable: true,
          hide_stats: false,
          display_probability: false,
          is_only_sell: false,
          open_wallet: false,
          display_new: false,
          disable_display_order_sort: false,
          restock_time: 0,
          enable_reset: false,
          restock: %{}
        }
      },
      "table:server.shopitem.xml" => %{
        @shop_id => %{
          @potion_entry_id => %{
            id: @potion_entry_id,
            shop_id: @shop_id,
            item_id: @potion_id,
            rarity: 1,
            cost: %{type: 0, item_id: 0, amount: 250, sale_amount: 0},
            sell_count: 0,
            category: "SH",
            requirements: %{
              guild_trophy: 0,
              achievement: %{id: 0, rank: 0},
              championship: %{rank: 0, join_count: 0},
              guild_npc: %{type: 0, level: 0},
              quest_alliance: %{type: 0, grade: 0}
            },
            restricted_buy: nil,
            sell_unit: 1,
            label: 0,
            icon_tag: "",
            wear_for_preview: false,
            random_option: false,
            probability: 10_000,
            is_premium_item: false
          },
          @gear_entry_id => %{
            id: @gear_entry_id,
            shop_id: @shop_id,
            item_id: @gear_id,
            rarity: 2,
            cost: %{type: 0, item_id: 0, amount: 1_000, sale_amount: 0},
            sell_count: 0,
            category: "EQ",
            requirements: %{
              guild_trophy: 0,
              achievement: %{id: 0, rank: 0},
              championship: %{rank: 0, join_count: 0},
              guild_npc: %{type: 0, level: 0},
              quest_alliance: %{type: 0, grade: 0}
            },
            restricted_buy: nil,
            sell_unit: 1,
            label: 0,
            icon_tag: "",
            wear_for_preview: false,
            random_option: false,
            probability: 10_000,
            is_premium_item: false
          }
        }
      }
    })

    character = insert_character()

    # tabs must exist before the inventory manager loads its state
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :consumable, slots: 84})
    Repo.insert!(%Schema.InventoryTab{character_id: character.id, tab: :gear, slots: 4})

    Repo.insert!(%Schema.Wallet{character_id: character.id, mesos: 10_000})

    start_inventory(character)

    %{character: character}
  end

  test "load builds the shop stock from metadata", %{character: character} do
    state = init_shop(character)

    {:reply, :ok, state} = load(state, character)

    assert state.active_shop.id == @shop_id
    assert state.shop_npc_id == @npc_id
    assert map_size(state.active_shop.items) == 2

    potion = state.active_shop.items[@potion_entry_id]
    assert potion.metadata.item_id == @potion_id
    assert potion.stock_count == 0
    assert potion.stock_purchased == 0
    assert %Schema.Item{} = potion.item

    assert_received {:push, _open}
    assert_received {:push, _load_items}
    assert_received {:push, _buy_back_count}
  end

  test "buy pays the shop price and delivers the item", %{character: character} do
    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    {:reply, :ok, _state} =
      Managers.Shop.handle_call({:buy, character, @potion_entry_id, 2}, from(), state)

    assert wallet(character).mesos == 10_000 - 2 * 250

    items = Managers.Inventory.list_tab_items(character.id, :consumable)
    assert Enum.map(items, & &1.amount) == [2]

    assert Repo.one(
             from i in Schema.Item,
               where: i.character_id == ^character.id and i.item_id == @potion_id,
               select: count()
           ) == 1

    assert_received {:push, _wallet}
    assert_received {:push, _add_item}
    assert_received {:push, _mark_new}
    assert_received {:push, _buy}
  end

  test "buy without mesos is rejected", %{character: character} do
    Context.Wallets.set(character, :mesos, 100)

    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    {:reply, :ok, _state} =
      Managers.Shop.handle_call({:buy, character, @potion_entry_id, 1}, from(), state)

    assert wallet(character).mesos == 100
    assert Managers.Inventory.list_tab_items(character.id, :consumable) == []

    assert_received {:push, _open}
    assert_received {:push, _load_items}
    assert_received {:push, _buy_back_count}
    assert_received {:push, _error}
  end

  test "buy needs a free slot or stack space", %{character: character} do
    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    # the gear tab holds 4 slots; buying 5 gear entries exhausts it
    Enum.each(1..4, fn _ ->
      {:reply, :ok, state} =
        Managers.Shop.handle_call({:buy, character, @gear_entry_id, 1}, from(), state)

      assert state.active_shop.items[@gear_entry_id]
    end)

    {:reply, :ok, _state} =
      Managers.Shop.handle_call({:buy, character, @gear_entry_id, 1}, from(), state)

    assert Managers.Inventory.free_slot_count(character.id, :gear) == 0

    assert Enum.count(
             Repo.all(
               from i in Schema.Item,
                 where: i.character_id == ^character.id and i.item_id == @gear_id
             )
           ) == 4
  end

  test "sell pays the sell price and stages a buy-back entry", %{character: character} do
    add_item(character, @potion_id, 5)

    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    [%{id: item_uid, amount: 5}] =
      Managers.Inventory.list_tab_items(character.id, :consumable)

    {:reply, :ok, state} =
      Managers.Shop.handle_call({:sell, character, item_uid, 2}, from(), state)

    # the shop pays the rarity's table price per sale, independent of quantity
    assert wallet(character).mesos == 10_000 + 100

    [{entry_id, entry}] = Map.to_list(state.buy_back_items)
    assert entry.item.amount == 2
    assert entry.price == 100
    assert is_integer(entry_id)

    consumed = Managers.Inventory.list_tab_items(character.id, :consumable)
    assert Enum.map(consumed, & &1.amount) == [3]

    assert_received {:push, _consume}
    assert_received {:push, _wallet}
    assert_received {:push, _load_buy_back}
  end

  test "buy-back returns the sold item and removes the entry", %{character: character} do
    add_item(character, @potion_id, 5)

    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    [%{id: item_uid}] = Managers.Inventory.list_tab_items(character.id, :consumable)

    {:reply, :ok, state} =
      Managers.Shop.handle_call({:sell, character, item_uid, 5}, from(), state)

    assert wallet(character).mesos == 10_000 + 100

    {:reply, :ok, state} =
      Managers.Shop.handle_call(
        {:purchase_buy_back, character, state.entry_id_counter},
        from(),
        state
      )

    assert state.buy_back_items == %{}
    assert wallet(character).mesos == 10_000

    # the item is back, freshly created as a new inventory row
    assert Enum.map(Managers.Inventory.list_tab_items(character.id, :consumable), & &1.amount) ==
             [
               5
             ]
  end

  test "buying from an unknown entry reports an error", %{character: character} do
    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    {:reply, :ok, _state} =
      Managers.Shop.handle_call({:buy, character, 99_999, 1}, from(), state)

    assert_received {:push, _error}
  end

  test "closing the talk clears the active shop", %{character: character} do
    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    {:reply, :ok, state} = Managers.Shop.handle_call(:clear_active_shop, from(), state)

    assert state.active_shop == nil
    assert state.shop_npc_id == 0
  end

  test "sell resolves metadata for database-loaded rows", %{character: character} do
    # rows loaded from the db carry no metadata document
    Managers.Inventory.stop(character.id)

    Repo.insert!(%Schema.Item{
      character_id: character.id,
      item_id: @potion_id,
      amount: 1,
      rarity: 1,
      inventory_slot: 0,
      inventory_tab: :consumable,
      location: :inventory,
      stats: %Ms2ex.Types.ItemStats{}
    })

    start_inventory(character)

    state = init_shop(character)
    {:reply, :ok, state} = load(state, character)

    [%{id: item_uid}] = Managers.Inventory.list_tab_items(character.id, :consumable)

    {:reply, :ok, state} =
      Managers.Shop.handle_call({:sell, character, item_uid, 1}, from(), state)

    assert Managers.Inventory.list_tab_items(character.id, :consumable) == []
    assert wallet(character).mesos == 10_000 + 100

    [{_entry_id, entry}] = Map.to_list(state.buy_back_items)
    assert entry.item.item_id == @potion_id
  end

  defp init_shop(character) do
    {:ok, state} = Managers.Shop.init(character)
    state
  end

  defp load(state, character) do
    Managers.Shop.handle_call({:load, character, @shop_id, @npc_id}, from(), state)
  end

  defp from, do: {self(), make_ref()}

  defp wallet(character),
    do: Repo.get_by!(Schema.Wallet, character_id: character.id)

  defp insert_character do
    account =
      Repo.insert!(%Schema.Account{
        username: "shop_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Shop#{System.unique_integer([:positive])}",
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
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), inventory_process(character.id))
  end

  defp inventory_process(character_id), do: :erlang.whereis(:"inventories:#{character_id}")

  defp add_item(character, item_id, amount) do
    item = Context.Items.init(item_id, %{rarity: 1, amount: amount})
    Managers.Inventory.add_item(character, item)
  end
end
