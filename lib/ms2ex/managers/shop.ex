defmodule Ms2ex.Managers.Shop do
  @moduledoc """
  Per-character vendor shop state: the open shop window, its instanced stock
  for limited-stock shops, and the session's buy-back list.

  Unlimited stock is rebuilt from metadata on every open. Shops with a
  restock policy (`enable_reset`) keep their rolled stock and per-item
  purchase counters until the restock window passes; that state persists per
  owner (account or character, per the shop's policy) through
  `Ms2ex.Context.Shops`.
  """

  use GenServer
  use Ms2ex.Managers.Managed, prefix: "shops", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @max_buy_back_items 12
  @restock_failsafe 10
  @never 9_223_372_036_854_775_807
  @day_seconds 86_400
  @default_reset_type Enums.ResetType.get_value(:default)

  def start(%Schema.Character{} = character) do
    case GenServer.start(__MODULE__, character, name: process_name(character.id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def stop(%Schema.Character{id: id}), do: stop(id)

  def stop(id) when is_integer(id) do
    case Process.whereis(process_name(id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  # ---- client API ----

  @doc "Opens the shop window of an npc (the npc id titles the window)."
  def load(%Schema.Character{} = character, shop_id, npc_id) do
    call(character.id, {:load, character, shop_id, npc_id})
  end

  def clear_active_shop(%Schema.Character{id: id}), do: clear_active_shop(id)

  def clear_active_shop(id) when is_integer(id), do: call(id, :clear_active_shop)

  @doc "Buys `quantity` of a stock entry of the open shop."
  def buy(%Schema.Character{} = character, shop_item_id, quantity) do
    call(character.id, {:buy, character, shop_item_id, quantity})
  end

  @doc "Sells `quantity` of an inventory item to the open shop."
  def sell(%Schema.Character{} = character, item_uid, quantity) do
    call(character.id, {:sell, character, item_uid, quantity})
  end

  @doc "Buys back a previously sold item."
  def purchase_buy_back(%Schema.Character{} = character, entry_id) do
    call(character.id, {:purchase_buy_back, character, entry_id})
  end

  @doc "Pays to restock the open limited-stock shop immediately."
  def instant_restock(%Schema.Character{} = character) do
    call(character.id, {:instant_restock, character})
  end

  @doc "Re-rolls the open limited-stock shop (free, on scheduled restocks)."
  def refresh(%Schema.Character{} = character) do
    call(character.id, {:refresh, character})
  end

  @doc "Zeroes the restock counters of day-interval shop data."
  def daily_reset(character_id), do: cast(character_id, {:reset_interval, :day})

  @doc "Zeroes the restock counters of week-interval shop data."
  def weekly_reset(character_id), do: cast(character_id, {:reset_interval, :week})

  # ---- Server Callbacks ----

  @impl true
  def init(%Schema.Character{} = character) do
    state = %{
      character: character,
      account_shop_data: shop_data_index(character.account_id),
      character_shop_data: shop_data_index(character.id),
      account_shop_item_data: shop_item_data_index(character.account_id),
      character_shop_item_data: shop_item_data_index(character.id),
      instanced_shops: %{},
      buy_back_items: %{},
      active_shop: nil,
      shop_npc_id: 0,
      entry_id_counter: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:load, character, shop_id, npc_id}, _from, state) do
    state = open_shop(character, shop_id, npc_id, state)
    {:reply, :ok, state}
  end

  def handle_call(:clear_active_shop, _from, state) do
    {:reply, :ok, %{state | active_shop: nil, shop_npc_id: 0}}
  end

  def handle_call({:buy, character, shop_item_id, quantity}, _from, state) do
    state = buy_item(character, shop_item_id, quantity, state)
    {:reply, :ok, state}
  end

  def handle_call({:sell, character, item_uid, quantity}, _from, state) do
    state = sell_item(character, item_uid, quantity, state)
    {:reply, :ok, state}
  end

  def handle_call({:purchase_buy_back, character, entry_id}, _from, state) do
    state = purchase_buy_back(character, entry_id, state)
    {:reply, :ok, state}
  end

  def handle_call({:instant_restock, character}, _from, state) do
    state = restock_now(character, state, pay?: true)
    {:reply, :ok, state}
  end

  def handle_call({:refresh, character}, _from, state) do
    state = restock_now(character, state, pay?: false)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:reset_interval, interval}, state) do
    {:noreply, reset_interval(state, Enums.ResetType.get_value(interval))}
  end

  # ---- shop assembly ----

  defp open_shop(character, shop_id, npc_id, state) do
    case Storage.Tables.Shop.get_meta(shop_id) do
      nil ->
        state

      metadata ->
        {shop, state} = build_shop(metadata, character, state)
        state = %{state | active_shop: shop, shop_npc_id: npc_id}
        push_open_shop(character, metadata, shop, state)
        state
    end
  end

  defp push_open_shop(character, metadata, shop, state) do
    push(character, Packets.Shop.open(shop, state.shop_npc_id, character))
    push(character, Packets.Shop.load_items(shop, character))
    push_buy_back(character, metadata, state)
  end

  defp push_buy_back(character, metadata, state) do
    unless Map.get(metadata, :is_only_sell, false) do
      buy_back_items = Map.values(state.buy_back_items)
      push(character, Packets.Shop.buy_back_item_count(length(buy_back_items)))

      unless buy_back_items == [] do
        push(character, Packets.Shop.load_buy_back(buy_back_items, character))
      end
    end
  end

  defp build_shop(metadata, character, state) do
    if Map.get(metadata, :enable_reset, false) do
      get_instanced_shop(metadata, character, state)
    else
      shop = %{
        id: metadata.id,
        metadata: metadata,
        restock_time: Map.get(metadata, :restock_time, 0),
        restock_count: 0,
        items: stock_items(metadata)
      }

      {shop, state}
    end
  end

  # instanced shops live for the session; an expired restock window is
  # rebuilt on the next login
  defp get_instanced_shop(metadata, character, state) do
    case Map.get(state.instanced_shops, metadata.id) do
      %{} = shop ->
        {shop, state}

      nil ->
        case shop_data(state, metadata.id) do
          nil ->
            open_new_instanced_shop(metadata, character, state)

          data ->
            reopen_shop(data, metadata, character, state)
        end
    end
  end

  defp open_new_instanced_shop(metadata, character, state) do
    restock_time = get_restock_time(metadata)
    {data, state} = create_shop_data(metadata, character, restock_time, state)
    create_instanced_shop(metadata, character, data, restock_time, state)
  end

  defp reopen_shop(data, metadata, character, state) do
    if data.restock_time >= now() do
      assemble_shop(metadata, data, state)
    else
      state = delete_shop_data(data, state)
      open_new_instanced_shop(metadata, character, state)
    end
  end

  # re-assembles an in-window shop: a fresh roll of the metadata stock with
  # the persisted items and purchase counters overlaid where they match
  defp assemble_shop(metadata, data, state) do
    items =
      case shop_item_data(state, metadata.id) do
        nil ->
          stock_items(metadata)

        item_data ->
          items = stock_items(metadata)

          Map.merge(items, item_data, fn _id, meta_item, data_item ->
            %{meta_item | item: data_item.item, stock_purchased: data_item.stock_purchased}
          end)
      end

    shop = %{
      id: metadata.id,
      metadata: metadata,
      restock_time: data.restock_time,
      restock_count: data.restock_count,
      items: items
    }

    state = put_in(state, [:instanced_shops, metadata.id], shop)
    {shop, state}
  end

  defp create_instanced_shop(metadata, character, data, restock_time, state) do
    state = delete_shop_item_data(metadata, character, state)

    items = stock_items(metadata)
    {_item_data, state} = create_shop_item_data(metadata, character, items, state)

    shop = %{
      id: metadata.id,
      metadata: metadata,
      restock_time: restock_time,
      restock_count: data.restock_count,
      items: items
    }

    state = put_in(state, [:instanced_shops, metadata.id], shop)
    {shop, state}
  end

  # persists the restock window of a shop (default-interval shops are not
  # persisted: their window is always the next minute)
  defp create_shop_data(metadata, character, restock_time, state) do
    case shop_data(state, metadata.id) do
      %{} = data ->
        {data, state}

      nil ->
        data = %Schema.CharacterShopData{
          owner_id: owner_id(metadata, character),
          shop_id: metadata.id,
          restock_time: restock_time,
          restock_count: 0,
          interval: restock_type(metadata)
        }

        data = persist_new_shop_data(data, metadata)
        {data, put_shop_data(state, metadata, data)}
    end
  end

  defp persist_new_shop_data(data, metadata) do
    if restock_type(metadata) == @default_reset_type do
      data
    else
      {:ok, persisted} = Context.Shops.create_shop_data(Map.from_struct(data))
      persisted
    end
  end

  # persists the rolled stock entries of a fresh restock
  defp create_shop_item_data(metadata, character, items, state) do
    owner_id = owner_id(metadata, character)
    persist? = restock_type(metadata) != @default_reset_type

    item_data =
      Map.new(items, fn {shop_item_id, shop_item} ->
        data = new_shop_item_data(metadata, owner_id, shop_item_id, shop_item, persist?)
        {shop_item_id, data}
      end)

    {item_data, put_shop_item_data(state, metadata, item_data)}
  end

  defp new_shop_item_data(metadata, owner_id, shop_item_id, shop_item, persist?) do
    data = %Schema.CharacterShopItemData{
      owner_id: owner_id,
      shop_id: metadata.id,
      shop_item_id: shop_item_id,
      stock_purchased: 0,
      item: shop_item.item
    }

    if persist? do
      case Context.Shops.create_shop_item_data(Map.from_struct(data)) do
        {:ok, persisted} -> persisted
        _error -> data
      end
    else
      data
    end
  end

  defp stock_items(metadata) do
    entries = Storage.Tables.ShopItems.list(metadata.id)

    items =
      if Map.get(metadata, :enable_reset, false) do
        roll_stock_items(metadata, entries)
      else
        Map.new(entries, fn {shop_item_id, entry} ->
          {shop_item_id, stock_item(shop_item_id, entry)}
        end)
      end

    Map.reject(items, fn {_shop_item_id, shop_item} -> is_nil(shop_item) end)
  end

  # limited-stock shops roll their entries: each metadata entry passes a
  # probability check until the restock range is filled
  defp roll_stock_items(metadata, entries) do
    restock = metadata.restock
    max_count = Map.get(restock, :max_item_count, 0)
    min_count = min(Map.get(restock, :min_item_count, 0), map_size(entries))

    roll_loop(entries, min_count, max_count, %{}, 0)
  end

  defp roll_loop(_entries, min_count, _max_count, items, failsafe)
       when map_size(items) >= min_count or failsafe >= @restock_failsafe do
    items
  end

  defp roll_loop(entries, min_count, max_count, items, failsafe) do
    items = roll_entries(entries, max_count, items)
    roll_loop(entries, min_count, max_count, items, failsafe + 1)
  end

  defp roll_entries(entries, max_count, items) do
    Enum.reduce_while(entries, items, fn {shop_item_id, entry}, items ->
      cond do
        map_size(items) >= max_count ->
          {:halt, items}

        Map.has_key?(items, shop_item_id) ->
          {:cont, items}

        :rand.uniform(10_000) > Map.get(entry, :probability, 0) ->
          {:cont, items}

        true ->
          {:cont, roll_entry(items, shop_item_id, entry)}
      end
    end)
  end

  defp roll_entry(items, shop_item_id, entry) do
    case stock_item(shop_item_id, entry) do
      nil -> items
      shop_item -> Map.put(items, shop_item_id, shop_item)
    end
  end

  defp stock_item(shop_item_id, entry) do
    case create_stock_item(
           Map.get(entry, :item_id),
           Map.get(entry, :rarity, 1),
           Map.get(entry, :sell_unit, 0)
         ) do
      nil ->
        nil

      item ->
        %{
          id: shop_item_id,
          metadata: entry,
          item: item,
          stock_count: Map.get(entry, :sell_count, 0),
          stock_purchased: 0
        }
    end
  end

  defp create_stock_item(item_id, rarity, amount) do
    case Storage.Items.get_meta(item_id) do
      nil ->
        nil

      metadata ->
        Context.Items.init(item_id, %{rarity: resolve_rarity(rarity, metadata), amount: amount})
    end
  end

  defp resolve_rarity(rarity, _metadata) when rarity > 0, do: rarity

  defp resolve_rarity(_rarity, %{option: %{constant_id: constant_id}}) when constant_id in 1..6,
    do: constant_id

  defp resolve_rarity(_rarity, _metadata), do: 1

  # ---- buy ----

  defp buy_item(_character, _shop_item_id, _quantity, %{active_shop: nil} = state), do: state

  defp buy_item(character, shop_item_id, quantity, state) do
    shop = state.active_shop

    case Map.get(shop.items, shop_item_id) do
      nil ->
        push(character, Packets.Shop.error(:invalid_item))
        state

      shop_item ->
        buy_item(character, shop, shop_item, quantity, state)
    end
  end

  defp buy_item(character, shop, shop_item, quantity, state) do
    with :ok <- check_restricted_buy(shop_item.metadata),
         :ok <- check_stock(shop, shop_item, quantity),
         :ok <- check_requirements(character, shop_item.metadata),
         :ok <- check_inventory_space(character, shop_item.metadata, quantity) do
      complete_purchase(character, shop, shop_item, quantity, state)
    else
      {:error, error} ->
        unless error == :silent, do: push(character, Packets.Shop.error(error))

        state
    end
  end

  # restricted entries can only be bought inside their window and on their
  # days of week
  defp check_restricted_buy(meta) do
    case Map.get(meta, :restricted_buy) do
      nil -> :ok
      restricted -> check_restricted_window(restricted)
    end
  end

  defp check_restricted_window(restricted) do
    now = now()
    start_time = Map.get(restricted, :start_time, 0)
    end_time = Map.get(restricted, :end_time, 0)

    if (start_time > 0 and now < start_time) or (end_time > 0 and now > end_time) do
      {:error, :invalid_item_cannot_buy_by_period}
    else
      check_time_ranges(restricted, now)
    end
  end

  defp check_time_ranges(restricted, now) do
    time_ranges = Map.get(restricted, :time_ranges, [])

    if time_ranges == [] do
      check_days(restricted)
    else
      seconds_of_day = rem(now, @day_seconds)

      in_range? =
        Enum.any?(time_ranges, fn range ->
          start = Map.get(range, :start, 0)
          finish = Map.get(range, :end, 0)
          start <= seconds_of_day and seconds_of_day <= finish
        end)

      if in_range?, do: check_days(restricted), else: {:error, :invalid_item_cannot_buy_by_period}
    end
  end

  defp check_days(restricted) do
    days = Map.get(restricted, :days, [])

    if days == [] do
      :ok
    else
      # shop days count sunday=1..saturday=7; Date.day_of_week monday=1..sunday=7
      today = rem(Date.day_of_week(Date.utc_today()), 7) + 1

      if today in days, do: :ok, else: {:error, :invalid_item_cannot_buy_by_period}
    end
  end

  defp check_stock(shop, shop_item, quantity) do
    if Map.get(shop.metadata, :enable_reset, false) and shop_item.stock_count > 0 and
         quantity > shop_item.stock_count - shop_item.stock_purchased do
      {:error, :lack_shopitem}
    else
      :ok
    end
  end

  defp check_requirements(character, meta) do
    requirements = Map.get(meta, :requirements, %{})
    achievement = Map.get(requirements, :achievement, %{})
    achievement_id = Map.get(achievement, :id, 0)

    if achievement_id > 0 and
         not Managers.Achievement.has_achievement?(
           character.id,
           achievement_id,
           Map.get(achievement, :rank, 0)
         ) do
      # the client shows no error for unmet achievement requirements
      {:error, :silent}
    else
      # TODO guild trophy requirement (guild achievement totals)
      :ok
    end
  end

  defp check_inventory_space(character, meta, quantity) do
    case create_stock_item(Map.get(meta, :item_id), Map.get(meta, :rarity, 1), quantity) do
      nil ->
        {:error, :invalid_item}

      item ->
        if can_add_item?(character, item) do
          :ok
        else
          {:error, :inventory}
        end
    end
  end

  # an entry fits when its tab has a free slot or the amount stacks onto the
  # character's existing stacks
  defp can_add_item?(character, item) do
    tab = Ms2ex.Types.Item.inventory_tab(item.metadata)

    if Managers.Inventory.free_slot_count(character.id, tab) > 0 do
      true
    else
      stack_limit = Map.get(item.metadata, :stack_limit, 1)

      stack_space(character, item) >= item.amount and stack_limit > 1
    end
  end

  defp stack_space(character, item) do
    character
    |> Managers.Inventory.list_items()
    |> Enum.filter(&(&1.item_id == item.item_id and &1.rarity == item.rarity))
    |> Enum.reduce(0, fn stack, space ->
      space + max(Map.get(stack.metadata || %{}, :stack_limit, 1) - stack.amount, 0)
    end)
  end

  defp price(meta, quantity) do
    cost = Map.get(meta, :cost, %{})
    sale_amount = Map.get(cost, :sale_amount, 0)

    if sale_amount > 0 do
      sale_amount * quantity
    else
      Map.get(cost, :amount, 0) * quantity
    end
  end

  defp complete_purchase(character, shop, shop_item, quantity, state) do
    meta = shop_item.metadata
    price = price(meta, quantity)

    with :ok <- pay(character, Map.get(meta, :cost, %{}), price),
         {:ok, state} <- update_stock(character, shop, shop_item, quantity, state) do
      item =
        create_stock_item(Map.get(meta, :item_id), Map.get(meta, :rarity, 1), quantity)

      case Managers.Inventory.add_item_or_mail(character, item) do
        {:ok, result} ->
          push(character, Packets.InventoryItem.add_item(result, character))
          push(character, Packets.InventoryItem.mark_item_new(new_inventory_item(result)))

          sell_unit = Map.get(meta, :sell_unit, 0)

          push(
            character,
            Packets.Shop.buy(
              Map.get(meta, :item_id),
              sell_unit * quantity,
              price,
              Map.get(meta, :rarity, 1)
            )
          )

          state

        {:mailed, _mail} ->
          state

        _error ->
          push(character, Packets.Shop.error(:inventory))
          state
      end
    else
      {:error, error} ->
        push(character, Packets.Shop.error(error))
        state
    end
  end

  defp update_stock(character, shop, shop_item, quantity, state) do
    if Map.get(shop.metadata, :enable_reset, false) and shop_item.stock_count > 0 do
      shop_item = %{shop_item | stock_purchased: shop_item.stock_purchased + quantity}
      shop = put_in(shop, [:items, shop_item.id], shop_item)
      state = put_in(state, [:active_shop, :items, shop_item.id], shop_item)

      persist_stock(state, shop, shop_item)

      sell_unit = Map.get(shop_item.metadata, :sell_unit, 0)
      push(character, Packets.Shop.update(shop_item.id, shop_item.stock_purchased * sell_unit))

      {:ok, state}
    else
      {:ok, state}
    end
  end

  defp persist_stock(state, shop, shop_item) do
    case shop_item_data(state, shop.id) |> Map.get(shop_item.id) do
      %Schema.CharacterShopItemData{} = data ->
        data = %{data | stock_purchased: shop_item.stock_purchased}
        Context.Shops.save_shop_item_data(data)

      _other ->
        :ok
    end
  end

  # ---- pay ----

  defp pay(character, cost, price) do
    case currency_type(Map.get(cost, :type, 0)) do
      :meso ->
        pay_mesos(character, price)

      currency when currency in [:meret, :event_meret, :game_meret] ->
        pay_merets(character, currency, price)

      :item ->
        pay_items(character, Map.get(cost, :item_id, 0), price)

      currency ->
        pay_wallet_currency(character, currency, price)
    end
  end

  defp pay_mesos(character, price) do
    wallet = Context.Wallets.find(character)

    if wallet && wallet.mesos >= price do
      Context.Wallets.update(character, :mesos, -price)
      :ok
    else
      {:error, :lack_meso}
    end
  end

  defp pay_merets(character, currency, price) do
    case Context.Wallets.debit(character, meret_wallet(currency), price) do
      {:ok, _wallet} -> :ok
      _error -> {:error, :lack_merat}
    end
  end

  defp pay_items(character, item_id, price) do
    case Managers.Inventory.consume_item_amount(character, item_id, price) do
      {:ok, results} ->
        Enum.each(results, &push(character, Packets.InventoryItem.consume(&1)))
        :ok

      _error ->
        {:error, {:lack_payment_item, item_id}}
    end
  end

  defp pay_wallet_currency(character, currency, price) do
    case wallet_currency(currency) do
      nil ->
        # TODO star point, mentor/mentee tokens, reverse coin, guild coin wallets
        {:error, :silent}

      wallet_currency ->
        wallet = Context.Wallets.find(character)
        balance = if wallet, do: Map.get(wallet, wallet_currency, 0), else: 0

        if balance >= price do
          Context.Wallets.update(character, wallet_currency, -price)
          :ok
        else
          {:error, :silent}
        end
    end
  end

  defp currency_type(type) when is_atom(type), do: type
  defp currency_type(type) when is_integer(type), do: Enums.ShopCurrencyType.get_key(type)
  defp currency_type(_type), do: :meso

  defp meret_wallet(:meret), do: :merets
  defp meret_wallet(:event_meret), do: :event_merets
  defp meret_wallet(:game_meret), do: :game_merets

  defp wallet_currency(:valor_token), do: :valor_tokens
  defp wallet_currency(:treva), do: :trevas
  defp wallet_currency(:rue), do: :rues
  defp wallet_currency(:havi_fruit), do: :havi_fruits
  defp wallet_currency(:meso_token), do: :meso_tokens
  defp wallet_currency(_currency), do: nil

  # ---- sell ----

  defp sell_item(_character, _item_uid, _quantity, %{active_shop: nil} = state), do: state

  defp sell_item(character, item_uid, quantity, state) do
    if Map.get(state.active_shop.metadata, :is_only_sell, false) do
      push(character, Packets.Shop.error(:cant_sell_to_only_sell_shop))
      state
    else
      do_sell(character, item_uid, quantity, state)
    end
  end

  defp do_sell(character, item_uid, quantity, state) do
    item =
      case Managers.Inventory.get(character, item_uid) do
        # inventory rows carry no metadata; resolve it from the storage cache
        %Schema.Item{} = item -> Context.Items.load_metadata(item)
        _other -> nil
      end

    sellable? =
      match?(%Schema.Item{}, item) and
        Map.get(Map.get(item.metadata || %{}, :limit, %{}), :shop_sell, false)

    if sellable? do
      consume(character, item, quantity, state)
    else
      state
    end
  end

  defp consume(character, item, quantity, state) do
    sold = %{item | amount: min(quantity, item.amount)}

    case Managers.Inventory.consume(item, quantity) do
      {:update, _updated} = result ->
        add_buy_back_item(character, sold, result, state)

      {:delete, _deleted} = result ->
        add_buy_back_item(character, sold, result, state)

      _error ->
        state
    end
  end

  defp add_buy_back_item(character, sold_item, consume_result, state) do
    metadata = sold_item.metadata || Storage.Items.get_meta(sold_item.item_id)

    sell_price =
      Formulas.Shop.sell_price(metadata, item_type(sold_item.item_id), sold_item.rarity)

    {state, removed_id} = trim_buy_back_items(character, state)

    state = %{state | entry_id_counter: state.entry_id_counter + 1}
    entry_id = state.entry_id_counter

    entry = %{id: entry_id, item: sold_item, added_time: now(), price: sell_price}
    state = put_in(state, [:buy_back_items, entry_id], entry)

    push(character, Packets.InventoryItem.consume(consume_result))
    Context.Wallets.update(character, :mesos, sell_price)

    if removed_id do
      push(character, Packets.Shop.remove_buy_back(removed_id))
    end

    push(character, Packets.Shop.load_buy_back([entry], character))

    state
  end

  # buy-back keeps a bounded list; the oldest entry is discarded to make room
  defp trim_buy_back_items(_character, state) do
    if map_size(state.buy_back_items) >= @max_buy_back_items do
      {id, oldest} = Enum.min_by(state.buy_back_items, fn {_id, entry} -> entry.added_time end)
      Managers.Inventory.delete(oldest.item)
      {state, id}
    else
      {state, nil}
    end
  end

  # the client's item type: {group, subtype} decoded from the item id
  defp item_type(item_id) do
    {div(item_id, 10_000_000), rem(item_id, 10_000_000) |> div(100_000)}
  end

  # ---- buy back ----

  defp purchase_buy_back(_character, _entry_id, %{active_shop: nil} = state), do: state

  defp purchase_buy_back(character, entry_id, state) do
    case Map.get(state.buy_back_items, entry_id) do
      nil ->
        push(character, Packets.Shop.error(:invalid_item))
        state

      entry ->
        buy_back_item(character, entry, state)
    end
  end

  defp buy_back_item(character, entry, state) do
    price = entry.price

    with :ok <- check_buy_back_space(character, entry),
         :ok <-
           pay(character, %{type: Enums.ShopCurrencyType.get_value(:meso), amount: price}, price),
         {:ok, result} <- Managers.Inventory.add_item(character, entry.item) do
      state = %{state | buy_back_items: Map.delete(state.buy_back_items, entry.id)}

      push(character, Packets.InventoryItem.add_item(result, character))
      push(character, Packets.InventoryItem.mark_item_new(new_inventory_item(result)))
      push(character, Packets.Shop.remove_buy_back(entry.id))

      state
    else
      {:error, error} ->
        push(character, Packets.Shop.error(error))
        state

      _error ->
        state
    end
  end

  defp check_buy_back_space(character, entry) do
    if can_add_item?(character, entry.item), do: :ok, else: {:error, :inventory}
  end

  # ---- restock ----

  defp restock_now(_character, %{active_shop: nil} = state, _pay?), do: state

  defp restock_now(character, state, pay?: pay?) do
    shop = state.active_shop
    metadata = shop.metadata
    restock = Map.get(metadata, :restock, %{})

    cond do
      not Map.get(metadata, :enable_reset, false) ->
        state

      pay? and Map.get(restock, :disable_instant_restock, false) ->
        state

      true ->
        restock_shop(character, metadata, restock, pay?, state)
    end
  end

  defp restock_shop(character, metadata, restock, pay?, state) do
    {cost, currency} =
      if Map.get(restock, :enable_price_multiplier, false) do
        {currency, cost} =
          Formulas.Shop.excess_restock_cost(
            currency_type(Map.get(restock, :excess_currency_type, 0)),
            active_restock_count(state, metadata)
          )

        {cost, currency}
      else
        {Map.get(restock, :price, 0), currency_type(Map.get(restock, :currency_type, 0))}
      end

    case maybe_pay(character, pay?, currency, cost) do
      :ok ->
        restocked = resupply_shop(character, metadata, restock, state)
        state = %{state | active_shop: elem(restocked, 1)}
        push_restocked_shop(character, elem(restocked, 0), state)
        state

      {:error, error} ->
        unless error == :silent, do: push(character, Packets.Shop.error(error))

        state
    end
  end

  defp resupply_shop(character, metadata, restock, state) do
    restock_time = get_instant_restock_time(Map.get(restock, :reset_type, 0))

    {data, state} =
      case shop_data(state, metadata.id) do
        %{} = data -> {%{data | restock_time: restock_time}, state}
        nil -> create_shop_data(metadata, character, restock_time, state)
      end

    data = %{data | restock_count: data.restock_count + 1}
    persist_shop_data(data, metadata)

    create_instanced_shop(metadata, character, data, data.restock_time, state)
  end

  defp push_restocked_shop(character, shop, state) do
    push(character, Packets.Shop.instant_restock())
    push(character, Packets.Shop.open(shop, state.shop_npc_id, character))
    push(character, Packets.Shop.load_items(shop, character))
  end

  defp maybe_pay(_character, false, _currency, _cost), do: :ok

  defp maybe_pay(character, true, currency, cost),
    do: pay(character, %{type: Enums.ShopCurrencyType.get_value(currency), amount: cost}, cost)

  defp active_restock_count(state, metadata) do
    case state.active_shop do
      %{id: id, restock_count: count} when id == metadata.id -> count
      _other -> 0
    end
  end

  defp persist_shop_data(data, metadata) do
    if restock_type(metadata) != @default_reset_type do
      Context.Shops.save_shop_data(data)
    end
  end

  # ---- resets ----

  defp reset_interval(state, target) do
    account_shop_data = reset_shop_data(state.account_shop_data, target)
    character_shop_data = reset_shop_data(state.character_shop_data, target)

    %{
      state
      | account_shop_data: account_shop_data,
        character_shop_data: character_shop_data,
        account_shop_item_data:
          reset_item_data(state.account_shop_item_data, account_shop_data, target),
        character_shop_item_data:
          reset_item_data(state.character_shop_item_data, character_shop_data, target),
        instanced_shops: reset_instanced_shops(state.instanced_shops, target)
    }
  end

  defp reset_shop_data(shop_data, target) do
    Map.new(shop_data, fn {shop_id, data} ->
      if data.interval == target do
        data = %{data | restock_count: 0}
        Context.Shops.save_shop_data(data)
        {shop_id, data}
      else
        {shop_id, data}
      end
    end)
  end

  defp reset_item_data(item_data, shop_data, target) do
    Map.new(item_data, fn {shop_id, items} ->
      {shop_id, reset_shop_items(items, shop_data, shop_id, target)}
    end)
  end

  defp reset_shop_items(items, shop_data, shop_id, target) do
    case Map.get(shop_data, shop_id) do
      %{interval: ^target} -> zero_stock_purchased(items)
      _other -> items
    end
  end

  defp zero_stock_purchased(items) do
    Map.new(items, fn {item_id, data} ->
      data = %{data | stock_purchased: 0}
      Context.Shops.save_shop_item_data(data)
      {item_id, data}
    end)
  end

  defp reset_instanced_shops(instanced_shops, target) do
    Map.new(instanced_shops, fn {shop_id, shop} ->
      {shop_id, reset_instanced_shop(shop, target)}
    end)
  end

  defp reset_instanced_shop(shop, target) do
    if restock_type(shop.metadata) == target do
      %{shop | restock_count: 0, items: zero_stock_items(shop.items)}
    else
      shop
    end
  end

  defp zero_stock_items(items) do
    Map.new(items, fn {item_id, item} -> {item_id, %{item | stock_purchased: 0}} end)
  end

  # ---- restock times ----

  # a fixed timestamp wins; otherwise the interval decides the next boundary
  defp get_restock_time(metadata) do
    case Map.get(metadata, :restock_time, 0) do
      restock_time when restock_time > 0 ->
        restock_time

      _ ->
        case Enums.ResetType.get_key(restock_type(metadata)) do
          :default -> next_minute()
          :day -> midnight(1)
          :week -> weekly_reset_time()
          :month -> next_month()
          _other -> @never
        end
    end
  end

  defp get_instant_restock_time(reset_type) do
    case Enums.ResetType.get_key(reset_type) do
      :default -> now() + 60
      :day -> now() + @day_seconds
      :week -> now() + 7 * @day_seconds
      :month -> month_later()
      _other -> @never
    end
  end

  # same calendar day next month, keeping the time of day
  defp month_later do
    now = DateTime.utc_now()
    month = now.month + 1

    year = if month > 12, do: now.year + 1, else: now.year
    month = if month > 12, do: month - 12, else: month
    day = min(now.day, Date.days_in_month(Date.new!(year, month, 1)))

    DateTime.new!(Date.new!(year, month, day), DateTime.to_time(now))
    |> DateTime.to_unix()
  end

  defp next_minute do
    now = now()
    now - rem(now, 60) + 60
  end

  defp midnight(days_ahead) do
    Date.utc_today()
    |> Date.add(days_ahead)
    |> DateTime.new!(Time.new!(0, 0, 0))
    |> DateTime.to_unix()
  end

  defp weekly_reset_time do
    Date.utc_today()
    |> Formulas.Shop.next_reset_day()
    |> DateTime.new!(Time.new!(0, 0, 0))
    |> DateTime.to_unix()
  end

  defp next_month do
    Date.utc_today()
    |> Date.beginning_of_month()
    |> Date.add(32)
    |> Date.beginning_of_month()
    |> DateTime.new!(Time.new!(0, 0, 0))
    |> DateTime.to_unix()
  end

  defp now, do: System.system_time(:second)

  # ---- state helpers ----

  defp shop_data_index(owner_id) do
    owner_id
    |> Context.Shops.list_shop_data()
    |> Map.new(&{&1.shop_id, &1})
  end

  defp shop_item_data_index(owner_id) do
    owner_id
    |> Context.Shops.list_shop_item_data()
    |> Enum.reduce(%{}, fn data, acc ->
      Map.update(
        acc,
        data.shop_id,
        %{data.shop_item_id => data},
        &Map.put(&1, data.shop_item_id, data)
      )
    end)
  end

  defp shop_data(state, shop_id) do
    Map.get(state.account_shop_data, shop_id) || Map.get(state.character_shop_data, shop_id)
  end

  defp shop_item_data(state, shop_id) do
    Map.get(state.account_shop_item_data, shop_id) ||
      Map.get(state.character_shop_item_data, shop_id)
  end

  defp owner_id(metadata, character) do
    if get_in(metadata, [:restock, :account_wide]), do: character.account_id, else: character.id
  end

  defp restock_type(metadata),
    do: get_in(metadata, [:restock, :reset_type]) || @default_reset_type

  defp put_shop_data(state, metadata, data) do
    if get_in(metadata, [:restock, :account_wide]) do
      put_in(state, [:account_shop_data, metadata.id], data)
    else
      put_in(state, [:character_shop_data, metadata.id], data)
    end
  end

  defp put_shop_item_data(state, metadata, item_data) do
    if get_in(metadata, [:restock, :account_wide]) do
      put_in(state, [:account_shop_item_data, metadata.id], item_data)
    else
      put_in(state, [:character_shop_item_data, metadata.id], item_data)
    end
  end

  defp delete_shop_item_data(metadata, character, state) do
    case shop_item_data(state, metadata.id) do
      nil ->
        state

      item_data ->
        owner_id = owner_id(metadata, character)

        Enum.each(item_data, fn {shop_item_id, _data} ->
          Context.Shops.delete_shop_item_data(owner_id, metadata.id, shop_item_id)
        end)

        state
    end
  end

  defp delete_shop_data(data, state) do
    state =
      if Map.has_key?(state.account_shop_data, data.shop_id) do
        %{state | account_shop_data: Map.delete(state.account_shop_data, data.shop_id)}
      else
        %{state | character_shop_data: Map.delete(state.character_shop_data, data.shop_id)}
      end

    Context.Shops.delete_shop_data(data.owner_id, data.shop_id)
    state
  end

  # the newest item of an add result: the created row, or the created part
  # of a stack split
  defp new_inventory_item(result), do: result |> Tuple.to_list() |> List.last()
end
