defmodule Ms2ex.Context.Inventory do
  @moduledoc """
  Context module for inventory-related operations.

  This module provides functions for managing character inventories,
  including adding, removing, updating, and organizing items.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Repo
  alias Ms2ex.Types

  import Ecto.Query, except: [update: 2]

  @doc """
  Gets an item from the inventory by the given attributes.

  ## Examples

      iex> get_by(%{character_id: 1, id: 123})
      %Schema.Item{}

      iex> get_by(%{character_id: 999, id: 456})
      nil
  """
  @spec get_by(map()) :: Schema.Item.t() | nil
  def get_by(attrs), do: Repo.get_by(Schema.Item, attrs)

  @doc """
  Gets all items belonging to a character.

  ## Examples

      iex> all(character)
      [%Schema.Item{}, %Schema.Item{}, ...]
  """
  @spec all(Schema.Character.t()) :: [Schema.Item.t()]
  def all(%Schema.Character{id: character_id}) do
    Schema.Item
    |> where([i], i.character_id == ^character_id)
    |> Repo.all()
  end

  @doc """
  Lists all items in a character's inventory (excluding equipped items).

  Returns items sorted by inventory slot.

  ## Examples

      iex> list_items(character)
      [%Schema.Item{location: :inventory}, ...]
  """
  @spec list_items(Schema.Character.t()) :: [Schema.Item.t()]
  def list_items(%Schema.Character{id: character_id}) do
    Schema.Item
    |> where([i], i.character_id == ^character_id and i.location == ^:inventory)
    |> order_by(asc: :inventory_slot)
    |> Repo.all()
  end

  @doc """
  Lists all inventory tabs for a character.

  ## Examples

      iex> list_tabs(character)
      [%Schema.InventoryTab{tab: :outfit}, ...]
  """
  @spec list_tabs(Schema.Character.t()) :: [Schema.InventoryTab.t()]
  def list_tabs(%Schema.Character{id: character_id}) do
    Schema.InventoryTab
    |> where([i], i.character_id == ^character_id)
    |> order_by(asc: :tab)
    |> Repo.all()
  end

  @doc """
  Lists items in a specific inventory tab.

  ## Examples

      iex> list_tab_items(character_id, :outfit)
      [%Schema.Item{inventory_tab: :outfit}, ...]
  """
  @spec list_tab_items(integer(), atom()) :: [Schema.Item.t()]
  def list_tab_items(character_id, tab) do
    Schema.Item
    |> where([i], i.character_id == ^character_id)
    |> where([i], i.location == ^:inventory and i.inventory_tab == ^tab)
    |> order_by(asc: :inventory_slot)
    |> Repo.all()
  end

  @doc """
  Gets an item by ID for a character.

  ## Examples

      iex> get(character, 123)
      %Schema.Item{}
  """
  @spec get(Schema.Character.t(), integer()) :: Schema.Item.t() | nil
  def get(%{id: char_id}, id) do
    get_by(character_id: char_id, id: id)
  end

  @doc """
  Adds an item to a character's inventory.

  Handles stackable items by finding existing stacks that can be increased.

  ## Examples

      iex> add_item(character, item)
      {:ok, {:create, %Schema.Item{}}}
  """
  @spec add_item(Schema.Character.t(), Schema.Item.t()) ::
          {:ok,
           {:create, Schema.Item.t()}
           | {:update, Schema.Item.t()}
           | {:update_and_create, {Schema.Item.t(), integer()}, Schema.Item.t()}}
  # Item is stackable
  def add_item(%Schema.Character{} = character, %Schema.Item{metadata: %{stack_limit: n}} = attrs)
      when n > 1 do
    result =
      Repo.transaction(fn ->
        case find_stack(character, attrs) do
          %Schema.Item{} = item ->
            update_or_create(character, item, attrs)

          nil ->
            create(character, attrs)
        end
      end)

    notify_item_added(character, result)
    result
  end

  # Item is not stackable
  def add_item(%Schema.Character{} = character, %Schema.Item{} = attrs) do
    case create(character, attrs) do
      {:create, item} ->
        result = {:ok, {:create, item}}
        notify_item_added(character, result)
        result

      other ->
        other
    end
  end

  # acquisition-driven quest conditions (`item_add`, `item_exist`); pushed
  # for every successful inventory insert/stack so progress tracks amount
  defp notify_item_added(character, {:ok, {_kind, item}}) do
    notify_item_conditions(character, item)
  end

  defp notify_item_added(character, {:ok, {_kind, {_updated, _amount}, item}}) do
    notify_item_conditions(character, item)
  end

  defp notify_item_added(_character, _result), do: :ok

  defp notify_item_conditions(character, item) do
    amount = Map.get(item, :amount, 0)

    Managers.Quest.update_conditions(character.id, :item_add, amount, "", 0, "", item.item_id)
    Managers.Quest.update_conditions(character.id, :item_exist, amount, "", 0, "", item.item_id)
  end

  @doc """
  Finds an existing stack of the same item that isn't at its stack limit.

  ## Examples

      iex> find_stack(character, item)
      %Schema.Item{amount: 5}
  """
  @spec find_stack(Schema.Character.t(), Schema.Item.t()) :: Schema.Item.t() | nil
  def find_stack(%{id: char_id}, %{item_id: item_id, metadata: meta}) do
    stack_limit = Map.get(meta, :stack_limit) || 1

    Schema.Item
    |> where([i], i.character_id == ^char_id)
    |> where([i], i.item_id == ^item_id and i.amount < ^stack_limit)
    |> order_by(desc: :amount)
    |> limit(1)
    |> Repo.one()
  end

  defp update_or_create(
         character,
         %{amount: amount, metadata: %{stack_limit: stack_limit}} = item,
         %{amount: new_amount} = attrs
       )
       when amount + new_amount > stack_limit do
    amount_added = stack_limit - amount
    amount_created = new_amount - amount_added
    attrs = %{attrs | amount: amount_created}

    with {:update, updated} <- update_qty(item, amount_added),
         {:create, created} <- create(character, attrs) do
      {:update_and_create, {updated, new_amount}, created}
    end
  end

  defp update_or_create(_character, item, %{amount: new_amount}) do
    update_qty(item, new_amount)
  end

  defp create(character, %{amount: n, metadata: meta} = attrs) when n > 0 do
    rarity = attrs.rarity || 1
    inventory_tab = Types.Item.inventory_tab(meta)
    slot = find_first_available_slot(character.id, inventory_tab)

    attrs = %{attrs | inventory_tab: inventory_tab, rarity: rarity, inventory_slot: slot}
    attrs = Map.from_struct(attrs)

    changeset =
      character
      |> Ecto.build_assoc(:inventory_items)
      |> Schema.Item.changeset(attrs)

    with {:ok, item} <- Repo.insert(changeset) do
      {:create, %{item | metadata: meta}}
    end
  end

  defp create(_character, _attrs), do: :nothing

  defp update_qty(%{id: id, metadata: meta}, new_amount) do
    Schema.Item
    |> where([i], i.id == ^id)
    |> Repo.update_all(inc: [amount: new_amount])

    item = Schema.Item |> Repo.get(id) |> Map.put(:metadata, meta)
    {:update, item}
  end

  @doc """
  Updates an item with the given attributes.

  ## Examples

      iex> update_item(item, %{amount: 5})
      {:ok, %Schema.Item{amount: 5}}
  """
  @spec update_item(Schema.Item.t() | Ecto.Changeset.t(), map()) ::
          {:ok, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def update_item(data, attrs) do
    data
    |> Schema.Item.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Consumes a given amount of an item.

  Reduces the item amount by the consumed amount, or deletes the item if amount would be zero.

  ## Examples

      iex> consume(item, 2)
      {:update, %Schema.Item{amount: 3}}

      iex> consume(item, 5)
      {:delete, %Schema.Item{}}
  """
  @spec consume(Schema.Item.t(), integer()) ::
          {:update, Schema.Item.t()} | {:delete, Schema.Item.t()}
  def consume(item, consumed \\ 1)

  def consume(%Schema.Item{amount: amount} = item, consumed) when amount > consumed do
    update_qty(item, -consumed)
  end

  def consume(%Schema.Item{} = item, _consumed), do: delete(item)

  @doc """
  Consumes an amount of an item across the character's carry stacks,
  deleting stacks emptied by the consumption. Must run inside the caller's
  transaction when atomicity matters. Returns per-stack results for
  inventory packets; `{:error, :insufficient_amount}` when the character
  holds fewer than the requested amount.
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
  Consumes each `%{item_id, amount}` pair from the character's carry stacks,
  loading every needed stack with a single query and deleting stacks emptied
  by the consumption. Pairs the inventory cannot cover are skipped so callers
  can keep processing (the completion counter no longer matches the live
  inventory in that case).
  """
  @spec consume_item_amounts(Schema.Character.t(), [map()]) ::
          {:ok, [{:update, Schema.Item.t()} | {:delete, Schema.Item.t()}]}
  def consume_item_amounts(%Schema.Character{} = character, consumables) do
    stacks =
      character
      |> owned_stacks(Enum.map(consumables, & &1.item_id))
      |> Enum.group_by(& &1.item_id)

    {results, _stacks} =
      Enum.flat_map_reduce(consumables, stacks, fn %{item_id: item_id, amount: amount}, stacks ->
        item_stacks = Map.get(stacks, item_id, [])

        if amount > 0 and total_amount(item_stacks) >= amount do
          {taken, remaining} = take_from_stacks(item_stacks, amount, [], [])
          {taken, Map.put(stacks, item_id, remaining)}
        else
          {[], stacks}
        end
      end)

    {:ok, results}
  end

  defp owned_stacks(%Schema.Character{id: character_id}, item_ids) do
    Schema.Item
    |> where([i], i.character_id == ^character_id and i.item_id in ^item_ids)
    |> where([i], i.location == ^:inventory)
    |> order_by(asc: :amount)
    |> Repo.all()
  end

  defp total_amount(stacks), do: Enum.reduce(stacks, 0, &(&1.amount + &2))

  # Splits the consumption across stacks (smallest first); `consume/2` writes
  # each partial update or deletion and returns its inventory packet entry
  defp take_from_stacks([], _amount, results, remaining),
    do: {Enum.reverse(results), Enum.reverse(remaining)}

  defp take_from_stacks([stack | rest], amount, results, remaining) do
    to_take = min(stack.amount, amount)
    result = consume(stack, to_take)

    case stack.amount - to_take do
      0 ->
        take_from_stacks(rest, amount - to_take, [result | results], remaining)

      left ->
        take_from_stacks(rest, amount - to_take, [result | results], [
          %{stack | amount: left} | remaining
        ])
    end
  end

  @doc """
  Deletes an item from the inventory.

  ## Examples

      iex> delete(item)
      {:delete, %Schema.Item{}}
  """
  @spec delete(Schema.Item.t()) :: {:delete, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Schema.Item{} = item) do
    with {:ok, item} <- Repo.delete(item) do
      {:delete, item}
    end
  end

  @doc """
  Checks if an item has expired.

  ## Examples

      iex> expired?(item)
      true
  """
  @spec expired?(Schema.Item.t()) :: boolean()
  def expired?(%Schema.Item{expires_at: nil}), do: false

  def expired?(%Schema.Item{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Finds the first available inventory slot in a given tab.

  ## Examples

      iex> find_first_available_slot(1, :outfit)
      5
  """
  @spec find_first_available_slot(integer(), atom()) :: integer() | {:error, :full_inventory}
  def find_first_available_slot(character_id, inventory_tab) do
    slots =
      Schema.Item
      |> select([i], i.inventory_slot)
      |> where([i], i.character_id == ^character_id)
      |> where([i], i.location == ^:inventory and i.inventory_tab == ^inventory_tab)
      |> order_by(asc: :inventory_slot)
      |> Repo.all()

    # TODO read inventory slots from DB
    Enum.find(0..149, fn slot -> not Enum.member?(slots, slot) end) || {:error, :full_inventory}
  end

  @doc """
  Gets the item in a specific inventory slot.

  ## Examples

      iex> item_in_slot(1, :outfit, 5)
      %Schema.Item{inventory_slot: 5}
  """
  @spec item_in_slot(integer(), atom(), integer()) :: Schema.Item.t() | nil
  def item_in_slot(char_id, tab, slot) do
    Schema.Item
    |> where([i], i.character_id == ^char_id)
    |> where([i], i.inventory_tab == ^tab and i.inventory_slot == ^slot)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Swaps an item to a new slot, handling any item that might already be in that slot.

  ## Examples

      iex> swap(item, 10)
      {:ok, 0}
  """
  @spec swap(Schema.Item.t(), integer()) :: {:ok, integer()} | {:error, any()}
  def swap(%Schema.Item{} = src_item, dst_slot) do
    Repo.transaction(fn ->
      case item_in_slot(src_item.character_id, src_item.inventory_tab, dst_slot) do
        %Schema.Item{} = dst_item ->
          src_slot = src_item.inventory_slot

          {:ok, src_item} = update_item(src_item, %{inventory_slot: nil})
          {:ok, dst_item} = update_item(dst_item, %{inventory_slot: src_slot})
          {:ok, _src_item} = update_item(src_item, %{inventory_slot: dst_slot})

          dst_item.id

        nil ->
          {:ok, _src_item} = update_item(src_item, %{inventory_slot: dst_slot})
          0
      end
    end)
  end

  @doc """
  Expands an inventory tab by adding additional slots.

  ## Examples

      iex> expand_tab(character, :outfit)
      %Schema.InventoryTab{slots: 36}
  """
  @spec expand_tab(Schema.Character.t(), atom()) :: Schema.InventoryTab.t()
  def expand_tab(%Schema.Character{id: character_id}, tab) do
    extra_slots = 6

    Schema.InventoryTab
    |> where([i], i.character_id == ^character_id and i.tab == ^tab)
    |> Repo.update_all(inc: [slots: extra_slots])

    Repo.get_by(Schema.InventoryTab, character_id: character_id, tab: tab)
  end

  @doc """
  Sorts items in a tab by item ID.

  ## Examples

      iex> sort_tab(character, :outfit)
      {:ok, [%Schema.Item{}, ...]}
  """
  @spec sort_tab(Schema.Character.t(), atom()) :: {:ok, [Schema.Item.t()]} | {:error, any()}
  def sort_tab(%Schema.Character{id: character_id}, inventory_tab) do
    Repo.transaction(fn ->
      Schema.Item
      |> where([i], i.character_id == ^character_id)
      |> where([i], i.location == ^:inventory and i.inventory_tab == ^inventory_tab)
      |> Repo.update_all(set: [inventory_slot: nil])

      Schema.Item
      |> where([i], i.character_id == ^character_id)
      |> where([i], i.location == ^:inventory and i.inventory_tab == ^inventory_tab)
      |> order_by(asc: :item_id)
      |> Repo.all()
      |> Enum.with_index()
      |> Enum.into([], fn {item, idx} ->
        {:ok, item} = update_item(item, %{inventory_slot: idx})
        item
      end)
    end)
  end

  @doc """
  Binds an item to a character (placeholder).

  ## Examples

      iex> bind(item)
      %Schema.Item{}
  """
  @spec bind(Schema.Item.t()) :: Schema.Item.t()
  def bind(%Schema.Item{} = item) do
    item
  end
end
