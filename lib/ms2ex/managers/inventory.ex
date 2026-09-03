defmodule Ms2ex.Managers.Inventory do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "inventories", key: :character_id

  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Ecto.Query, except: [update: 2]

  @fallback_tab_size 48

  # The inventory manager owns every item row of a character: reads are
  # served from memory, mutations are written through to the database, and
  # slot allocation is an in-memory scan. Rows are kept without their
  # metadata documents; callers fetch metadata from the storage cache when
  # they need it.

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

  @impl GenServer
  def init(%Schema.Character{id: character_id}) do
    items = Repo.all(from i in Schema.Item, where: i.character_id == ^character_id)
    tabs = Repo.all(from t in Schema.InventoryTab, where: t.character_id == ^character_id)

    {:ok, %{character_id: character_id, items: items, tabs: tabs}}
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

  def handle_call({:item_in_slot, tab, slot}, _from, state) do
    item =
      Enum.find(
        state.items,
        &(&1.location == :inventory and &1.inventory_tab == tab and &1.inventory_slot == slot)
      )

    {:reply, item, state}
  end

  def handle_call({:first_available_slot, tab}, _from, state),
    do: {:reply, first_available_slot(state, tab), state}

  def handle_call({:free_slot_count, tab}, _from, state) do
    size = tab_size(state, tab)
    occupied = occupied_slots(state, tab) |> Enum.count(&(&1 >= 0 and &1 < size))

    {:reply, max(size - occupied, 0), state}
  end

  def handle_call({:find_stack, attrs}, _from, state),
    do: {:reply, find_stack(state, attrs), state}

  # ---- mutations ----

  def handle_call({:add_item, attrs}, _from, state) do
    {result, state} = add_item(state, attrs)
    {:reply, result, state}
  end

  def handle_call({:consume, item, consumed}, _from, state) do
    case get_item(state, item.id) do
      %Schema.Item{} = owned ->
        {result, state} = consume(state, owned, consumed)
        {:reply, result, state}

      nil ->
        {:reply, consume_fallback(item, consumed), state}
    end
  end

  def handle_call({:consume_item_amounts, consumables}, _from, state) do
    {results, state} = consume_item_amounts(state, consumables)
    {:reply, {:ok, results}, state}
  end

  def handle_call({:delete, uid}, _from, state) do
    case get_item(state, uid) do
      %Schema.Item{} = item ->
        case Repo.delete(item) do
          {:ok, deleted} ->
            {:reply, {:delete, deleted}, %{state | items: List.delete(state.items, item)}}

          error ->
            {:reply, error, state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}
    end
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
    {result, state} = sort_tab(state, tab)
    {:reply, result, state}
  end

  def handle_call({:expand_tab, tab}, _from, state) do
    extra_slots = 6

    tabs =
      Enum.map(state.tabs, fn tab_row ->
        if tab_row.tab == tab do
          from(t in Schema.InventoryTab, where: t.id == ^tab_row.id)
          |> Repo.update_all(inc: [slots: extra_slots])

          %{tab_row | slots: tab_row.slots + extra_slots}
        else
          tab_row
        end
      end)

    {:reply, Enum.find(tabs, &(&1.tab == tab)), %{state | tabs: tabs}}
  end

  defp get_item(state, uid), do: Enum.find(state.items, &(&1.id == uid))

  defp carry_items(state), do: Enum.filter(state.items, &(&1.location == :inventory))

  # ---- stacking & creation ----

  # stackable items merge onto existing stacks first
  defp add_item(state, %Schema.Item{metadata: %{stack_limit: n}} = attrs) when n > 1 do
    case find_stack(state, attrs) do
      %Schema.Item{} = item ->
        {result, state} = update_or_create(state, item, attrs, n)
        {result, state}

      nil ->
        case create(state, attrs) do
          {{:create, item}, state} -> {{:ok, {:create, item}}, state}
          {other, state} -> {other, state}
        end
    end
  end

  defp add_item(state, %Schema.Item{} = attrs) do
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
    attrs = Map.put(attrs, :amount, amount_created)

    {{:update, updated}, state} = update_qty(state, item, amount_added)
    {{:create, created}, state} = create(state, attrs)

    {{:update_and_create, {updated, new_amount}, created}, state}
  end

  defp update_or_create(state, item, %{amount: new_amount}, _stack_limit) do
    update_qty(state, item, new_amount)
  end

  defp create(state, %{amount: n, metadata: meta} = attrs) when n > 0 do
    rarity = attrs.rarity || 1
    inventory_tab = Types.Item.inventory_tab(meta)
    slot = first_available_slot(state, inventory_tab)

    item_attrs =
      attrs
      |> Map.put(:inventory_tab, inventory_tab)
      |> Map.put(:rarity, rarity)
      |> Map.put(:inventory_slot, slot)
      |> Map.from_struct()

    changeset =
      %Schema.Character{id: state.character_id}
      |> Ecto.build_assoc(:inventory_items)
      |> Schema.Item.changeset(item_attrs)

    case Repo.insert(changeset) do
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
    case Repo.delete(item) do
      {:ok, deleted} ->
        {{:delete, deleted}, %{state | items: List.delete(state.items, item)}}

      error ->
        {error, state}
    end
  end

  # falls back to the caller's row when the manager does not own the item
  defp consume_fallback(%{amount: amount} = item, consumed) when amount > consumed do
    from(i in Schema.Item, where: i.id == ^item.id)
    |> Repo.update_all(inc: [amount: -consumed])

    {:update, %{item | amount: amount - consumed}}
  end

  defp consume_fallback(item, _consumed) do
    case Repo.delete(item) do
      {:ok, deleted} -> {:delete, deleted}
      error -> error
    end
  end

  # consumes across the carry stacks: each pair is taken from its stacks
  # (smallest first), pairs the inventory cannot cover are skipped
  defp consume_item_amounts(state, consumables) do
    item_ids = Enum.map(consumables, & &1.item_id)

    stacks =
      state.items
      |> Enum.filter(&(&1.location == :inventory and &1.item_id in item_ids))
      |> Enum.sort_by(& &1.amount)
      |> Enum.group_by(& &1.item_id)

    {results, stacks} = take_consumables(consumables, stacks, [])

    {List.flatten(results), apply_consumption(state, results, stacks)}
  end

  defp take_consumables([], stacks, results), do: {Enum.reverse(results), stacks}

  defp take_consumables([%{item_id: item_id, amount: amount} | rest], stacks, results) do
    item_stacks = Map.get(stacks, item_id, [])

    if amount > 0 and total_amount(item_stacks) >= amount do
      {taken, remaining} = take_from_stacks(item_stacks, amount, [], [])
      stacks = Map.put(stacks, item_id, remaining)

      take_consumables(rest, stacks, [Enum.reverse(taken) | results])
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
  defp apply_consumption(state, results, _stacks) do
    ops = List.flatten(results)

    {deleted_ids, updates} =
      Enum.reduce(ops, {[], %{}}, fn
        {:delete, stack}, {deleted, updates} -> {[stack.id | deleted], updates}
        {:update, stack}, {deleted, updates} -> {deleted, Map.put(updates, stack.id, stack)}
      end)

    unless deleted_ids == [] do
      from(i in Schema.Item, where: i.id in ^deleted_ids) |> Repo.delete_all()
    end

    Enum.each(updates, fn {id, stack} ->
      from(i in Schema.Item, where: i.id == ^id)
      |> Repo.update_all(set: [amount: stack.amount])
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
    case persist_update(item, attrs) do
      {:ok, updated} ->
        {{:ok, updated}, replace_item(state, updated)}

      error ->
        {error, state}
    end
  end

  defp persist_update(item, attrs) do
    item
    |> Schema.Item.changeset(attrs)
    |> Repo.update()
  end

  defp update_qty(state, item, delta) do
    from(i in Schema.Item, where: i.id == ^item.id)
    |> Repo.update_all(inc: [amount: delta])

    updated = %{item | amount: item.amount + delta}
    state = replace_item(state, updated)
    {{:update, updated}, state}
  end

  defp replace_item(state, updated) do
    items =
      Enum.map(state.items, fn item ->
        if item.id == updated.id, do: updated, else: item
      end)

    %{state | items: items}
  end

  # ---- slots ----

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
            {:ok, _} = persist_update(src_item, %{inventory_slot: nil})
            {:ok, _} = persist_update(dst_item, %{inventory_slot: src_slot})
            {:ok, _} = persist_update(src_item, %{inventory_slot: dst_slot})

            dst_item.id

          nil ->
            {:ok, _} = persist_update(src_item, %{inventory_slot: dst_slot})
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

  defp sort_tab(state, tab) do
    result =
      Repo.transaction(fn ->
        tab_items = tab_items(state, tab)
        clear_slots(tab_items)
        sorted = Enum.sort_by(tab_items, & &1.item_id)
        assign_slots(sorted)
        sorted
      end)

    case result do
      {:ok, sorted} ->
        apply_sorted_slots(state, sorted)

      error ->
        {error, state}
    end
  end

  defp clear_slots(tab_items) do
    Enum.each(tab_items, fn item ->
      from(i in Schema.Item, where: i.id == ^item.id)
      |> Repo.update_all(set: [inventory_slot: nil])
    end)
  end

  defp assign_slots(sorted) do
    sorted
    |> Enum.with_index()
    |> Enum.each(fn {item, idx} ->
      from(i in Schema.Item, where: i.id == ^item.id)
      |> Repo.update_all(set: [inventory_slot: idx])
    end)
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

    {{:ok, sorted}, %{state | items: items}}
  end

  defp tab_items(state, tab) do
    Enum.filter(state.items, &(&1.location == :inventory and &1.inventory_tab == tab))
  end

  defp sort_by_slot(items), do: Enum.sort_by(items, & &1.inventory_slot)
end
