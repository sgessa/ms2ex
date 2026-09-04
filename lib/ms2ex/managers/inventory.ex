defmodule Ms2ex.Managers.Inventory do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "inventories", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @fallback_tab_size 48

  # The inventory manager owns every item row of a character: reads are
  # served from memory, mutations are applied to memory and persisted
  # through `Ms2ex.Context.Inventory`. Rows are kept without their metadata
  # documents; callers fetch metadata from the storage cache when they need
  # it.

  def start(%Schema.Character{id: id} = character) do
    case GenServer.start(__MODULE__, character, name: process_name(id)) do
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

  def alive?(id), do: Process.whereis(process_name(id)) != nil

  # ---- client API ----

  @doc "Gets an item by uid."
  @spec get(Schema.Character.t(), integer()) :: Schema.Item.t() | nil
  def get(%Schema.Character{id: character_id}, uid), do: call(character_id, {:get, uid})

  @doc "Lists every item of a character, equipped and carried."
  def all(%Schema.Character{id: character_id}), do: call(character_id, :all)

  @doc "Lists a character's carried items, sorted by slot."
  def list_items(%Schema.Character{id: character_id}), do: call(character_id, :list_items)

  @doc "Lists a character's inventory tab rows."
  def list_tabs(%Schema.Character{id: character_id}), do: call(character_id, :list_tabs)

  @doc "Lists a character's carried items in a tab, sorted by slot."
  def list_tab_items(character_id, tab), do: call(character_id, {:list_tab_items, tab})

  @doc "Lists a character's equipped items."
  def list_equips(%Schema.Character{id: character_id}), do: call(character_id, :list_equips)

  @doc "Finds the first free slot of a tab."
  @spec find_first_available_slot(integer(), atom()) :: integer() | {:error, :full_inventory}
  def find_first_available_slot(character_id, tab),
    do: call(character_id, {:first_available_slot, tab})

  @doc "Counts the free slots of a tab."
  @spec free_slot_count(integer(), atom()) :: non_neg_integer()
  def free_slot_count(character_id, tab), do: call(character_id, {:free_slot_count, tab})

  @doc """
  Adds an item, merging onto existing stacks when stackable. Acquisition
  flows notify the quest manager themselves (see
  `Ms2ex.Managers.Quest.notify_item_acquired/2`).
  """
  @spec add_item(Schema.Character.t(), Schema.Item.t()) ::
          {:ok,
           {:create, Schema.Item.t()}
           | {:update, Schema.Item.t()}
           | {:update_and_create, {Schema.Item.t(), integer()}, Schema.Item.t()}}
  def add_item(%Schema.Character{id: character_id}, item) do
    call(character_id, {:add_item, item})
  end

  @doc "Updates an item's fields, writing through."
  @spec update_item(Schema.Item.t() | Ecto.Changeset.t(), map()) ::
          {:ok, Schema.Item.t()} | {:error, any()}
  def update_item(%Schema.Item{id: id, character_id: character_id}, attrs) do
    call(character_id, {:update_item, id, attrs})
  end

  def update_item(
        %Ecto.Changeset{data: %Schema.Item{character_id: character_id}} = changeset,
        attrs
      ) do
    call(character_id, {:update_item_changeset, changeset, attrs})
  end

  @doc """
  Consumes an amount of an item, deleting it when emptied.
  """
  @spec consume(Schema.Item.t(), integer()) ::
          {:update, Schema.Item.t()} | {:delete, Schema.Item.t()} | {:error, :not_found}
  def consume(%Schema.Item{} = item, consumed \\ 1) do
    call(item.character_id, {:consume, item, consumed})
  end

  @doc """
  Consumes an amount across the character's carry stacks; returns
  `{:error, :insufficient_amount}` when the stacks cannot cover it.
  """
  @spec consume_item_amount(Schema.Character.t(), integer(), integer()) ::
          {:ok, [{:update, Schema.Item.t()} | {:delete, Schema.Item.t()}]}
          | {:error, :insufficient_amount}
  def consume_item_amount(%Schema.Character{} = character, item_id, amount)
      when is_integer(item_id) and is_integer(amount) and amount > 0 do
    case consume_item_amounts(character, [%{item_id: item_id, amount: amount}]) do
      {:ok, []} -> {:error, :insufficient_amount}
      {:ok, results} -> {:ok, results}
    end
  end

  @doc """
  Consumes each `%{item_id, amount}` pair from the carry stacks. Pairs the
  inventory cannot cover are skipped so callers can keep processing (the
  completion counter no longer matches the live inventory in that case).
  """
  @spec consume_item_amounts(Schema.Character.t(), [map()]) ::
          {:ok, [{:update, Schema.Item.t()} | {:delete, Schema.Item.t()}]}
  def consume_item_amounts(%Schema.Character{id: character_id}, consumables) do
    call(character_id, {:consume_item_amounts, consumables})
  end

  @doc "Deletes an item."
  @spec delete(Schema.Item.t()) :: {:delete, Schema.Item.t()} | {:error, any()}
  def delete(%Schema.Item{id: id, character_id: character_id}) do
    call(character_id, {:delete, id})
  end

  @doc "Swaps an item into a slot, displacing whatever occupies it."
  @spec swap(Schema.Item.t(), integer()) :: {:ok, integer()} | {:error, any()}
  def swap(%Schema.Item{id: id, character_id: character_id}, dst_slot) do
    call(character_id, {:swap, id, dst_slot})
  end

  @doc "Sorts a tab's carried items by item id."
  @spec sort_tab(Schema.Character.t(), atom()) :: {:ok, [Schema.Item.t()]} | {:error, any()}
  def sort_tab(%Schema.Character{id: character_id}, tab) do
    call(character_id, {:sort_tab, tab})
  end

  @doc "Expands a tab by six slots."
  @spec expand_tab(Schema.Character.t(), atom()) :: Schema.InventoryTab.t()
  def expand_tab(%Schema.Character{id: character_id}, tab) do
    call(character_id, {:expand_tab, tab})
  end

  @doc """
  Equips an item into the requested slot, binding it first when its
  metadata marks it bind-on-equip.
  """
  @spec equip(Schema.Item.t(), atom()) :: {:ok, Schema.Item.t()} | {:error, any()}
  def equip(%Schema.Item{} = item, equip_slot) do
    item
    |> Schema.Item.bind_if_needed(:equip)
    |> update_item(%{
      equip_slot: equip_slot,
      inventory_slot: nil,
      location: :equipment
    })
  end

  @doc """
  Moves an equipped item back to the inventory. Prefers `preferred_slot`
  while it is free, else the first open slot in the tab; the item's equip
  slot is cleared.
  """
  @spec move_to_inventory(Schema.Item.t(), integer() | nil) ::
          {:ok, Schema.Item.t()} | {:error, :full_inventory} | {:error, :not_found}
  def move_to_inventory(%Schema.Item{id: id, character_id: character_id}, preferred_slot \\ nil) do
    call(character_id, {:move_to_inventory, id, preferred_slot})
  end

  @doc "Checks whether an item's expiry date has passed."
  @spec expired?(Schema.Item.t()) :: boolean()
  def expired?(%Schema.Item{expires_at: nil}), do: false

  def expired?(%Schema.Item{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc "Placeholder bind marker."
  @spec bind(Schema.Item.t()) :: Schema.Item.t()
  def bind(%Schema.Item{} = item), do: item

  # ---- server callbacks ----

  @impl GenServer
  def init(%Schema.Character{id: character_id}) do
    items = Context.Inventory.list_items(character_id)
    tabs = Context.Inventory.list_tabs(character_id)

    {:ok, %{character_id: character_id, items: items, tabs: tabs, lock_staging: []}}
  end

  # ---- reads ----

  @impl true
  def handle_call(:all, _from, state), do: {:reply, state.items, state}

  def handle_call({:get, uid}, _from, state), do: {:reply, get_item(state, uid), state}

  def handle_call(:list_items, _from, state),
    do: {:reply, carry_items(state) |> sort_by_slot(), state}

  def handle_call({:list_tab_items, tab}, _from, state),
    do: {:reply, tab_items(state, tab) |> sort_by_slot(), state}

  def handle_call(:list_equips, _from, state),
    do: {:reply, Enum.filter(state.items, &(&1.location == :equipment)), state}

  def handle_call(:list_tabs, _from, state), do: {:reply, state.tabs, state}

  def handle_call({:first_available_slot, tab}, _from, state),
    do: {:reply, first_available_slot(state, tab), state}

  def handle_call({:free_slot_count, tab}, _from, state) do
    size = tab_size(state, tab)
    occupied = occupied_slots(state, tab) |> Enum.count(&(&1 >= 0 and &1 < size))

    {:reply, max(size - occupied, 0), state}
  end

  # ---- mutations ----

  def handle_call({:add_item, attrs}, _from, state) do
    {result, state} = apply_add_item(state, attrs)
    {:reply, result, state}
  end

  def handle_call({:update_item, uid, attrs}, _from, state) do
    case get_item(state, uid) do
      %Schema.Item{} = item ->
        {result, state} = update_item(state, item, attrs)
        {:reply, result, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:update_item_changeset, changeset, attrs}, _from, state) do
    case get_item(state, changeset.data.id) do
      %Schema.Item{} = item ->
        {result, state} = update_item(state, item, Map.merge(changeset.changes, attrs))
        {:reply, result, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:consume, item, consumed}, _from, state) do
    case get_item(state, item.id) do
      %Schema.Item{} = owned ->
        {result, state} = consume(state, owned, consumed)
        {:reply, result, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:consume_item_amounts, consumables}, _from, state) do
    {results, state} = apply_consume_item_amounts(state, consumables)
    {:reply, {:ok, results}, state}
  end

  def handle_call({:delete, uid}, _from, state) do
    case get_item(state, uid) do
      %Schema.Item{} = item ->
        case Context.Inventory.delete_item(item) do
          {:ok, deleted} ->
            {:reply, {:delete, deleted}, %{state | items: List.delete(state.items, item)}}

          error ->
            {:reply, error, state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:move_to_inventory, uid, preferred_slot}, _from, state) do
    case get_item(state, uid) do
      %Schema.Item{} = item ->
        {result, state} = apply_move_to_inventory(state, item, preferred_slot)
        {:reply, result, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:swap, uid, dst_slot}, _from, state) do
    case get_item(state, uid) do
      %Schema.Item{} = src_item ->
        {result, state} = swap(state, src_item, dst_slot)
        {:reply, result, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:sort_tab, tab}, _from, state) do
    {result, state} = apply_sort_tab(state, tab)
    {:reply, result, state}
  end

  # ---- item locks ----

  def handle_call(:lock_reset, _from, state),
    do: {:reply, :ok, %{state | lock_staging: []}}

  def handle_call({:lock_stage, uid}, _from, state) do
    case get_item(state, uid) do
      %Schema.Item{} ->
        index = first_free_index(state.lock_staging)
        state = %{state | lock_staging: state.lock_staging ++ [{index, uid}]}
        {:reply, {:ok, index}, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:lock_unstage, uid}, _from, state) do
    case Enum.find(state.lock_staging, fn {_index, staged_uid} -> staged_uid == uid end) do
      staged when staged != nil ->
        {_index, _} = staged
        {:reply, :ok, %{state | lock_staging: List.delete(state.lock_staging, staged)}}

      nil ->
        {:reply, :error, state}
    end
  end

  def handle_call({:lock_commit, unlock}, _from, state) do
    {updated, state} = lock_commit(state, unlock)
    {:reply, {:ok, updated}, state}
  end

  def handle_call({:expand_tab, tab}, _from, state) do
    extra_slots = 6
    tab_row = Enum.find(state.tabs, &(&1.tab == tab))
    :ok = Context.Inventory.expand_tab(tab_row.id, extra_slots)
    updated = %{tab_row | slots: tab_row.slots + extra_slots}

    tabs = Enum.map(state.tabs, &if(&1.tab == tab, do: updated, else: &1))

    {:reply, updated, %{state | tabs: tabs}}
  end

  # ---- stacking & creation ----

  defp get_item(state, uid), do: Enum.find(state.items, &(&1.id == uid))

  defp carry_items(state), do: Enum.filter(state.items, &(&1.location == :inventory))

  # stackable items merge onto existing stacks first
  defp apply_add_item(state, %Schema.Item{metadata: %{stack_limit: n}} = attrs) when n > 1 do
    case find_stack(state, attrs) do
      %Schema.Item{} = item ->
        update_or_create(state, item, attrs, n)

      nil ->
        case create(state, attrs) do
          {{:create, item}, state} -> {{:ok, {:create, item}}, state}
          {other, state} -> {other, state}
        end
    end
  end

  defp apply_add_item(state, %Schema.Item{} = attrs) do
    case create(state, attrs) do
      {{:create, item}, state} -> {{:ok, {:create, item}}, state}
      {other, state} -> {other, state}
    end
  end

  defp find_stack(state, %{item_id: item_id, metadata: meta}) do
    stack_limit = Map.get(meta, :stack_limit) || 1

    state.items
    |> Enum.filter(
      &(&1.item_id == item_id and &1.location == :inventory and &1.amount < stack_limit)
    )
    |> Enum.max_by(& &1.amount, fn -> nil end)
  end

  defp update_or_create(
         state,
         %{amount: amount} = item,
         %{amount: new_amount} = attrs,
         stack_limit
       )
       when amount + new_amount > stack_limit do
    amount_added = stack_limit - amount
    amount_created = new_amount - amount_added

    {{:update, updated}, state} = update_qty(state, item, amount_added)
    {{:create, created}, state} = create(state, Map.put(attrs, :amount, amount_created))

    {{:update_and_create, {updated, new_amount}, created}, state}
  end

  defp update_or_create(state, item, %{amount: new_amount}, _stack_limit) do
    update_qty(state, item, new_amount)
  end

  defp create(state, %{amount: n, metadata: meta} = attrs) when n > 0 do
    inventory_tab = Types.Item.inventory_tab(meta)
    slot = first_available_slot(state, inventory_tab)

    attrs =
      attrs
      |> Map.put(:inventory_tab, inventory_tab)
      |> Map.put(:inventory_slot, slot)

    case Context.Inventory.insert_item(state.character_id, attrs) do
      {:ok, item} ->
        {{:create, item}, %{state | items: state.items ++ [item]}}

      error ->
        {error, state}
    end
  end

  defp create(state, _attrs), do: {:nothing, state}

  # ---- consumption ----

  defp consume(state, %{amount: amount} = item, consumed) when amount > consumed do
    update_qty(state, item, -consumed)
  end

  defp consume(state, item, _consumed) do
    case Context.Inventory.delete_item(item) do
      {:ok, deleted} ->
        {{:delete, deleted}, %{state | items: List.delete(state.items, item)}}

      error ->
        {error, state}
    end
  end

  # consumes across the carry stacks: each pair is taken from its stacks
  # (smallest first), pairs the inventory cannot cover are skipped
  defp apply_consume_item_amounts(state, consumables) do
    item_ids = Enum.map(consumables, & &1.item_id)

    stacks =
      state.items
      |> Enum.filter(&(&1.location == :inventory and &1.item_id in item_ids))
      |> Enum.sort_by(&{&1.amount, &1.id})
      |> Enum.group_by(& &1.item_id)

    {results, _stacks} = take_consumables(consumables, stacks, [])

    {List.flatten(results), apply_consumption(state, results)}
  end

  defp take_consumables([], stacks, results), do: {Enum.reverse(results), stacks}

  defp take_consumables([%{item_id: item_id, amount: amount} | rest], stacks, results) do
    item_stacks = Map.get(stacks, item_id, [])

    if amount > 0 and total_amount(item_stacks) >= amount do
      {taken, remaining} = take_from_stacks(item_stacks, amount, [], [])
      stacks = Map.put(stacks, item_id, remaining)

      # take_from_stacks already returns its results chronologically
      take_consumables(rest, stacks, [taken | results])
    else
      take_consumables(rest, stacks, results)
    end
  end

  defp total_amount(stacks), do: Enum.reduce(stacks, 0, &(&1.amount + &2))

  defp take_from_stacks([], _amount, taken, remaining),
    do: {Enum.reverse(taken), Enum.reverse(remaining)}

  defp take_from_stacks([stack | rest], amount, taken, remaining) do
    to_take = min(stack.amount, amount)
    left = stack.amount - to_take

    if left == 0 do
      take_from_stacks(rest, amount - to_take, [{:delete, stack} | taken], remaining)
    else
      updated = %{stack | amount: left}

      take_from_stacks(rest, amount - to_take, [{:update, updated} | taken], [
        updated | remaining
      ])
    end
  end

  # persists the planned consumption: deletes emptied stacks, updates the
  # surviving amounts, and drops/updates the in-memory copies to match
  defp apply_consumption(state, results) do
    ops = List.flatten(results)

    {deleted_ids, updates} =
      Enum.reduce(ops, {[], %{}}, fn
        {:delete, stack}, {deleted, updates} -> {[stack.id | deleted], updates}
        {:update, stack}, {deleted, updates} -> {deleted, Map.put(updates, stack.id, stack)}
      end)

    unless deleted_ids == [] do
      :ok = Context.Inventory.delete_items(deleted_ids)
    end

    Enum.each(updates, fn {id, stack} ->
      :ok = Context.Inventory.set_amount(id, stack.amount)
    end)

    items =
      Enum.flat_map(state.items, fn item ->
        cond do
          item.id in deleted_ids -> []
          Map.has_key?(updates, item.id) -> [Map.fetch!(updates, item.id)]
          true -> [item]
        end
      end)

    %{state | items: items}
  end

  # ---- generic updates ----

  defp update_item(state, item, attrs) do
    case Context.Inventory.update_item(item, attrs) do
      {:ok, updated} ->
        {{:ok, updated}, replace_item(state, updated)}

      error ->
        {error, state}
    end
  end

  defp update_qty(state, item, delta) do
    :ok = Context.Inventory.update_amount(item.id, delta)

    updated = %{item | amount: item.amount + delta}
    {{:update, updated}, replace_item(state, updated)}
  end

  defp replace_item(state, updated) do
    items =
      Enum.map(state.items, fn item ->
        if item.id == updated.id, do: updated, else: item
      end)

    %{state | items: items}
  end

  # ---- move & slots ----

  defp apply_move_to_inventory(state, item, preferred_slot) do
    case resolve_slot(state, item.inventory_tab, preferred_slot) do
      {:ok, slot} ->
        attrs = %{equip_slot: :NONE, inventory_slot: slot, location: :inventory}

        case Context.Inventory.update_item(item, attrs) do
          {:ok, updated} ->
            {{:ok, updated}, replace_item(state, updated)}

          error ->
            {error, state}
        end

      error ->
        {error, state}
    end
  end

  # prefers the requested slot while it lies in bounds and is still free,
  # else falls back to the first open slot in the tab
  defp resolve_slot(state, tab, preferred_slot) when is_integer(preferred_slot) do
    last_slot = tab_size(state, tab) - 1

    if preferred_slot in 0..last_slot and
         preferred_slot not in occupied_slots(state, tab) do
      {:ok, preferred_slot}
    else
      resolve_slot(state, tab, nil)
    end
  end

  defp resolve_slot(state, tab, _preferred_slot) do
    case first_available_slot(state, tab) do
      {:error, _reason} = error -> error
      slot -> {:ok, slot}
    end
  end

  defp first_available_slot(state, tab) do
    occupied = occupied_slots(state, tab)
    last_slot = tab_size(state, tab) - 1

    Enum.find(0..last_slot, fn slot -> not Enum.member?(occupied, slot) end) ||
      {:error, :full_inventory}
  end

  defp occupied_slots(state, tab) do
    state.items
    |> Enum.filter(&(&1.location == :inventory and &1.inventory_tab == tab))
    |> Enum.map(& &1.inventory_slot)
    |> Enum.sort()
  end

  defp tab_size(state, tab) do
    case Enum.find(state.tabs, &(&1.tab == tab)) do
      %Schema.InventoryTab{slots: slots} when is_integer(slots) and slots > 0 -> slots
      _ -> Map.get(Schema.InventoryTab.default_slots(), tab, @fallback_tab_size)
    end
  end

  # ---- swap & sort ----

  defp swap(state, src_item, dst_slot) do
    dst_item =
      Enum.find(
        state.items,
        &(&1.location == :inventory and &1.inventory_tab == src_item.inventory_tab and
            &1.inventory_slot == dst_slot)
      )

    src_slot = src_item.inventory_slot

    result =
      Repo.transaction(fn ->
        case dst_item do
          %Schema.Item{} = dst_item ->
            {:ok, _} = Context.Inventory.update_item(src_item, %{inventory_slot: nil})
            {:ok, _} = Context.Inventory.update_item(dst_item, %{inventory_slot: src_slot})
            {:ok, _} = Context.Inventory.update_item(src_item, %{inventory_slot: dst_slot})

            dst_item.id

          nil ->
            {:ok, _} = Context.Inventory.update_item(src_item, %{inventory_slot: dst_slot})
            0
        end
      end)

    case result do
      {:ok, dst_uid} ->
        state =
          case dst_item do
            %Schema.Item{} = dst_item ->
              state
              |> replace_item(%{src_item | inventory_slot: dst_slot})
              |> replace_item(%{dst_item | inventory_slot: src_slot})

            nil ->
              replace_item(state, %{src_item | inventory_slot: dst_slot})
          end

        {{:ok, dst_uid}, state}

      error ->
        {error, state}
    end
  end

  defp apply_sort_tab(state, tab) do
    result =
      Repo.transaction(fn ->
        items = tab_items(state, tab)
        Context.Inventory.clear_slots(Enum.map(items, & &1.id))

        items
        |> Enum.sort_by(& &1.item_id)
        |> Enum.with_index()
        |> Enum.map(fn {item, idx} ->
          :ok = Context.Inventory.assign_slot(item.id, idx)
          %{item | inventory_slot: idx}
        end)
      end)

    case result do
      {:ok, sorted} ->
        {{:ok, sorted}, apply_sorted_slots(state, sorted)}

      error ->
        {error, state}
    end
  end

  defp apply_sorted_slots(state, sorted) do
    slots = Map.new(sorted, fn item -> {item.id, item.inventory_slot} end)

    items =
      Enum.map(state.items, fn item ->
        case Map.fetch(slots, item.id) do
          {:ok, slot} -> %{item | inventory_slot: slot}
          :error -> item
        end
      end)

    %{state | items: items}
  end

  defp tab_items(state, tab) do
    Enum.filter(state.items, &(&1.location == :inventory and &1.inventory_tab == tab))
  end

  # ---- item locks ----

  defp first_free_index(staging) do
    used = MapSet.new(Enum.map(staging, fn {index, _uid} -> index end))

    Enum.find(0..255, fn index -> not MapSet.member?(used, index) end) || 255
  end

  # applies the staged lock requests: items are locked or unlocked and the
  # staging list is cleared; unlock marks the item with an unlock timestamp
  defp lock_commit(state, unlock) do
    {updated, state} =
      Enum.flat_map_reduce(state.lock_staging, state, fn {_index, uid}, state ->
        case get_item(state, uid) do
          %Schema.Item{} = item ->
            {changed, state} = set_lock(state, item, unlock)
            {changed, state}

          nil ->
            {[], state}
        end
      end)

    {updated, %{state | lock_staging: []}}
  end

  defp set_lock(state, item, unlock) do
    locked? = not unlock
    attrs = %{is_locked: locked?, unlocks_at: unlock_time(unlock)}

    case update_item(state, item, attrs) do
      {{:ok, updated}, state} ->
        {[updated], state}

      {_error, state} ->
        {[], state}
    end
  end

  # locking stamps now; unlocking stamps the 72-hour unlock-process window
  # the client renders while the item counts down
  defp unlock_time(unlock) do
    seconds =
      if unlock do
        Storage.Tables.Constants.get(:item_un_lock_time) || 259_200
      else
        0
      end

    DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)
  end

  defp sort_by_slot(items), do: Enum.sort_by(items, & &1.inventory_slot)
end
