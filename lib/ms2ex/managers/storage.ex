defmodule Ms2ex.Managers.Storage do
  @moduledoc """
  Per-account bank storage: the item rows (account-owned `inventory_items`),
  the stored mesos and the purchased slot expansion. The process lives only
  while the storage window is open — the client's load request starts it and
  its close request stops it; every mutation persists immediately.
  """

  use GenServer
  use Ms2ex.Managers.Managed, prefix: "storages", key: :account_id

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @base_storage_count 36
  @expand_row_count 6
  @max_meso 9_223_372_036_854_775_807
  @load_batch_size 10

  def start(%Schema.Character{account_id: account_id}), do: start(account_id)

  def start(account_id) when is_integer(account_id) do
    case GenServer.start(__MODULE__, account_id, name: process_name(account_id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def stop(%Schema.Character{account_id: account_id}), do: stop(account_id)

  def stop(account_id) when is_integer(account_id) do
    case Process.whereis(process_name(account_id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  # ---- client API ----

  @doc "Sends the full storage window contents."
  def load(%Schema.Character{} = character), do: call(character, {:load, character})

  @doc "Moves an inventory item (or part of it) into storage."
  def deposit(%Schema.Character{} = character, uid, slot, amount) do
    call(character, {:deposit, character, uid, slot, amount})
  end

  @doc "Moves a storage item (or part of it) back into the inventory."
  def withdraw(%Schema.Character{} = character, uid, slot, amount) do
    call(character, {:withdraw, character, uid, slot, amount})
  end

  @doc "Swaps a storage item with whatever occupies the target slot."
  def move(%Schema.Character{} = character, uid, dst_slot) do
    call(character, {:move, character, uid, dst_slot})
  end

  def deposit_mesos(%Schema.Character{} = character, amount),
    do: call(character, {:deposit_mesos, character, amount})

  def withdraw_mesos(%Schema.Character{} = character, amount),
    do: call(character, {:withdraw_mesos, character, amount})

  @doc "Buys one more storage row with merets."
  def expand(%Schema.Character{} = character), do: call(character, {:expand, character})

  @doc "Compacts the storage rows by item id."
  def sort(%Schema.Character{} = character), do: call(character, {:sort, character})

  @doc "Destroys a stored item."
  def delete(%Schema.Character{} = character, uid), do: call(character, {:delete, character, uid})

  @doc "Closes the storage window (stops the process)."
  def close(%Schema.Character{} = character), do: stop(character)

  # ---- Server Callbacks ----

  @impl true
  def init(account_id) do
    storage =
      case Context.Storages.get_info(account_id) do
        %Schema.AccountStorage{} = storage ->
          storage

        nil ->
          {:ok, storage} = Context.Storages.create_info(account_id)
          storage
      end

    items =
      account_id
      |> Context.Storages.list_items()
      |> Map.new(fn item -> {item.id, Context.Items.load_metadata(item)} end)

    {:ok,
     %{
       account_id: account_id,
       storage: storage,
       mesos: storage.mesos,
       expand: storage.expand,
       items: items
     }}
  end

  @impl true
  def handle_call({:load, character}, _from, state) do
    push_load(character, state)
    {:reply, :ok, state}
  end

  def handle_call({:deposit, character, uid, slot, amount}, _from, state) do
    {:reply, :ok, deposit(character, uid, slot, amount, state)}
  end

  def handle_call({:withdraw, character, uid, slot, amount}, _from, state) do
    {:reply, :ok, withdraw(character, uid, slot, amount, state)}
  end

  def handle_call({:move, character, uid, dst_slot}, _from, state) do
    {:reply, :ok, move_item(character, uid, dst_slot, state)}
  end

  def handle_call({:deposit_mesos, character, amount}, _from, state) do
    {:reply, :ok, deposit_mesos(character, amount, state)}
  end

  def handle_call({:withdraw_mesos, character, amount}, _from, state) do
    {:reply, :ok, withdraw_mesos(character, amount, state)}
  end

  def handle_call({:expand, character}, _from, state) do
    {:reply, :ok, expand(character, state)}
  end

  def handle_call({:sort, character}, _from, state) do
    {:reply, :ok, sort(character, state)}
  end

  def handle_call({:delete, character, uid}, _from, state) do
    {:reply, :ok, delete(character, uid, state)}
  end

  # ---- deposit ----

  defp deposit(character, uid, slot, amount, state) when amount > 0 do
    case inventory_item(character, uid) do
      %{amount: owned} = item when owned >= amount ->
        deposit_item(character, item, slot, amount, state)

      _other ->
        push(character, Packets.StorageInventory.error(:invalid_count))
        state
    end
  end

  defp deposit(_character, _uid, _slot, _amount, state), do: state

  defp deposit_item(character, item, slot, amount, state) do
    overflow = stack_overflow(state, item, amount)

    if open_slots(state) == 0 and overflow == amount do
      # nothing stacks and no slot is free
      push(character, Packets.StorageInventory.error(:store_full))
      state
    else
      amount = if open_slots(state) == 0, do: amount - overflow, else: amount

      case Managers.Inventory.consume(item, amount) do
        {:update, _remaining} = result ->
          push(character, Packets.InventoryItem.consume(result))
          store(character, %{item | amount: amount}, slot, state)

        {:delete, _deleted} = result ->
          push(character, Packets.InventoryItem.consume(result))
          store(character, %{item | amount: amount}, slot, state)

        _error ->
          state
      end
    end
  end

  # stores the removed portion: the requested slot wins when free, then the
  # item stacks, the remainder goes to the first open slot
  defp store(character, portion, slot, state) do
    if valid_slot?(state, slot) and slot_free?(state, slot) do
      create_stored_item(character, portion, slot, state)
    else
      {state, portion} = stack_into_storage(character, portion, state)

      if portion.amount > 0 do
        create_stored_item(character, portion, first_open_slot(state), state)
      else
        state
      end
    end
  end

  defp create_stored_item(character, portion, slot, state) do
    portion = %{
      portion
      | id: nil,
        character_id: nil,
        account_id: state.account_id,
        inventory_slot: slot,
        # storage rows are flat: the tab is a neutral bucket, withdrawals
        # re-derive the real tab from metadata
        inventory_tab: :misc,
        location: :inventory
    }

    {:ok, stored} = Context.Storages.create_item(portion)
    stored = Context.Items.load_metadata(stored)
    state = put_in(state, [:items, stored.id], stored)
    push(character, Packets.StorageInventory.add(stored, character))
    state
  end

  # merges the portion into existing stacks; returns the still-unstacked part
  defp stack_into_storage(character, portion, state) do
    if stack_limit(portion) <= 1 do
      {state, portion}
    else
      state.items
      |> Map.values()
      |> Enum.sort_by(& &1.inventory_slot)
      |> Enum.reduce_while({state, portion}, fn stack, acc ->
        merge_into_stack(character, stack, acc)
      end)
    end
  end

  defp merge_into_stack(_character, _stack, {state, %{amount: 0} = portion}),
    do: {:halt, {state, portion}}

  defp merge_into_stack(character, stack, {state, portion}) do
    room = stack_limit(stack) - stack.amount

    if room <= 0 do
      {:cont, {state, portion}}
    else
      moved = min(room, portion.amount)
      Context.Storages.update_amount(stack.id, moved)
      stack = %{stack | amount: stack.amount + moved}
      portion = %{portion | amount: portion.amount - moved}
      state = put_in(state, [:items, stack.id], stack)

      push(character, Packets.StorageInventory.update(stack.id, stack.amount))

      if portion.amount == 0, do: {:halt, {state, portion}}, else: {:cont, {state, portion}}
    end
  end

  # ---- withdraw ----

  defp withdraw(character, uid, slot, amount, state) when amount > 0 do
    case Map.get(state.items, uid) do
      %{amount: stored} = item when stored >= amount ->
        # TODO character-bound items can only be withdrawn by their binder
        #      (bound items carry no persisted owner yet)
        withdraw_item(character, item, slot, amount, state)

      _other ->
        push(character, Packets.StorageInventory.error(:invalid_count))
        state
    end
  end

  defp withdraw(_character, _uid, _slot, _amount, state), do: state

  defp withdraw_item(character, item, slot, amount, state) do
    portion = %{item | amount: min(amount, item.amount)}

    if can_add?(character, portion) do
      {state, portion} = take_storage_item(character, item, amount, state)
      add_to_inventory(character, portion, slot, state)
    else
      push(character, Packets.StorageInventory.error(:code))
      state
    end
  end

  # removes the withdrawn part from storage, pushing the storage-side packets
  defp take_storage_item(character, item, amount, state) when item.amount > amount do
    Context.Storages.update_amount(item.id, -amount)
    remaining = %{item | amount: item.amount - amount}
    state = put_in(state, [:items, item.id], remaining)

    push(character, Packets.StorageInventory.update(item.id, remaining.amount))
    {state, %{item | amount: amount}}
  end

  defp take_storage_item(character, item, _amount, state) do
    Context.Storages.delete_item(item)
    state = %{state | items: Map.delete(state.items, item.id)}

    push(character, Packets.StorageInventory.remove(item.id))
    {state, item}
  end

  defp add_to_inventory(character, portion, slot, state) do
    portion = %{
      portion
      | id: nil,
        character_id: character.id,
        account_id: nil,
        inventory_slot: slot,
        inventory_tab: Types.Item.inventory_tab(portion.metadata),
        location: :inventory
    }

    case Managers.Inventory.add_item(character, portion) do
      {:ok, result} ->
        push(character, Packets.InventoryItem.add_item(result, character))
        state

      _error ->
        state
    end
  end

  # ---- move ----

  defp move_item(character, uid, dst_slot, state) do
    if valid_slot?(state, dst_slot) and Map.has_key?(state.items, uid) do
      do_move(character, uid, dst_slot, state)
    else
      state
    end
  end

  defp do_move(character, uid, dst_slot, state) do
    src = state.items[uid]
    src_slot = src.inventory_slot

    {state, displaced} =
      case Enum.find(state.items, fn {_uid, item} -> item.inventory_slot == dst_slot end) do
        nil ->
          {state, nil}

        {_uid, dst} ->
          Context.Storages.update_item_slot(dst.id, src_slot)
          dst = %{dst | inventory_slot: src_slot}
          {put_in(state, [:items, dst.id], dst), dst}
      end

    Context.Storages.update_item_slot(src.id, dst_slot)
    state = put_in(state, [:items, src.id], %{src | inventory_slot: dst_slot})

    push(
      character,
      Packets.StorageInventory.move((displaced && displaced.id) || 0, src_slot, uid, dst_slot)
    )

    state
  end

  # ---- mesos ----

  defp deposit_mesos(character, amount, state) when amount >= 0 do
    if state.mesos + amount > @max_meso do
      push(character, Packets.StorageInventory.error(:deposit_invalid_money))
      state
    else
      case Managers.Wallet.debit(character, :mesos, amount) do
        {:ok, _wallet} ->
          state = %{state | mesos: state.mesos + amount}
          persist_info(state)

          push(character, Packets.StorageInventory.update_mesos(state.mesos))
          state

        _error ->
          push(character, Packets.StorageInventory.error(:deposit_invalid_money))
          state
      end
    end
  end

  defp deposit_mesos(_character, _amount, state), do: state

  defp withdraw_mesos(character, amount, state) when amount >= 0 do
    if amount > state.mesos do
      push(character, Packets.StorageInventory.error(:deposit_invalid_money))
      state
    else
      state = %{state | mesos: state.mesos - amount}
      persist_info(state)
      Managers.Wallet.earn(character, :mesos, amount)

      push(character, Packets.StorageInventory.update_mesos(state.mesos))
      state
    end
  end

  defp withdraw_mesos(_character, _amount, state), do: state

  # ---- expand ----

  defp expand(character, state) do
    new_size = size(state) + @expand_row_count
    max_size = Storage.Tables.Constants.get(:store_expand_max_slot_count)
    price = Ms2ex.Constants.get(:storage_expand_price1_row)

    if new_size > max_size do
      push(character, Packets.StorageInventory.error(:expand_max))
      state
    else
      if charge_merets(character, price) do
        state = %{state | expand: state.expand + @expand_row_count}
        persist_info(state)
        push_load(character, state)
        state
      else
        push(character, Packets.StorageInventory.error(:cannot_charge_merat))
        state
      end
    end
  end

  # a zero price (the client table's default) expands for free
  defp charge_merets(_character, 0), do: true

  defp charge_merets(character, price) do
    match?({:ok, _wallet}, Managers.Wallet.debit(character, :merets, price))
  end

  # ---- sort ----

  # compacts the rows ordered by item id, then rarity, then amount; the
  # window is re-sent with the load sequence, which the client re-renders
  # (its reload command never redraws the window)
  defp sort(character, state) do
    state =
      state.items
      |> Map.values()
      |> Enum.sort_by(&{&1.item_id, &1.rarity, &1.amount})
      |> Enum.with_index(fn item, slot -> {slot, item} end)
      |> Enum.reduce(state, fn {slot, item}, state ->
        if item.inventory_slot != slot do
          Context.Storages.update_item_slot(item.id, slot)
        end

        put_in(state, [:items, item.id], %{item | inventory_slot: slot})
      end)

    push_load(character, state)
    state
  end

  # ---- delete ----

  defp delete(character, uid, state) do
    case Map.get(state.items, uid) do
      nil ->
        state

      item ->
        Context.Storages.delete_item(item)
        state = %{state | items: Map.delete(state.items, uid)}

        push(character, Packets.StorageInventory.remove(uid))
        state
    end
  end

  # ---- helpers ----

  defp persist_info(state) do
    Context.Storages.save_info(%{state.storage | mesos: state.mesos, expand: state.expand})
  end

  defp push_load(character, state) do
    push(character, Packets.StorageInventory.reset())
    push(character, Packets.StorageInventory.slots_expanded(state.expand))
    push(character, Packets.StorageInventory.update_mesos(state.mesos))
    push(character, Packets.StorageInventory.slots_used(map_size(state.items)))

    state.items
    |> Map.values()
    |> Enum.sort_by(& &1.inventory_slot)
    |> Enum.chunk_every(@load_batch_size)
    |> Enum.each(fn batch -> push(character, Packets.StorageInventory.load(batch, character)) end)
  end

  defp inventory_item(character, uid) do
    case Managers.Inventory.get(character, uid) do
      %Schema.Item{} = item -> Context.Items.load_metadata(item)
      _other -> nil
    end
  end

  defp size(state), do: @base_storage_count + state.expand
  defp open_slots(state), do: size(state) - map_size(state.items)
  defp valid_slot?(state, slot), do: slot >= 0 and slot < size(state)

  defp slot_free?(state, slot) do
    not Enum.any?(state.items, fn {_uid, item} -> item.inventory_slot == slot end)
  end

  defp first_open_slot(state) do
    Enum.find(0..(size(state) - 1), fn slot -> slot_free?(state, slot) end)
  end

  # the amount of `item` that cannot stack onto the current storage stacks
  defp stack_overflow(state, item, amount) do
    if stack_limit(item) <= 1 do
      amount
    else
      space =
        state.items
        |> Map.values()
        |> Enum.filter(&(&1.item_id == item.item_id and &1.rarity == item.rarity))
        |> Enum.reduce(0, fn stack, space ->
          space + max(stack_limit(stack) - stack.amount, 0)
        end)

      max(amount - space, 0)
    end
  end

  # an entry fits when its tab has a free slot or the amount stacks onto the
  # character's existing stacks
  defp can_add?(character, item) do
    tab = Types.Item.inventory_tab(item.metadata)

    if Managers.Inventory.free_slot_count(character.id, tab) > 0 do
      true
    else
      stack_limit(item) > 1 and stack_space(character, item) >= item.amount
    end
  end

  defp stack_space(character, item) do
    character
    |> Managers.Inventory.list_items()
    |> Enum.filter(&(&1.item_id == item.item_id and &1.rarity == item.rarity))
    |> Enum.reduce(0, fn stack, space ->
      space + max(stack_limit(stack) - stack.amount, 0)
    end)
  end

  defp stack_limit(%{metadata: nil}), do: 1

  defp stack_limit(%{metadata: metadata}), do: Map.get(metadata, :stack_limit, 1)
end
