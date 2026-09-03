defmodule Ms2ex.Context.Inventory do
  @moduledoc """
  Context module for inventory-related operations.

  Every item of a character is owned by the character's inventory manager
  (`Ms2ex.Managers.Inventory`): reads are served from its memory and
  mutations are written through to the database. The manager runs for the
  lifetime of a game session; there is no database path beside it.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Schema

  @doc """
  Gets an item from the inventory by the given attributes.

  ## Examples

      iex> get_by(%{character_id: 1, id: 123})
      %Schema.Item{}

      iex> get_by(%{character_id: 999, id: 456})
      nil
  """
  @spec get_by(map()) :: Schema.Item.t() | nil
  def get_by(%{character_id: character_id, id: id}) do
    Managers.Inventory.call(character_id, {:get, id})
  end

  @doc """
  Gets all items belonging to a character.

  ## Examples

      iex> all(character)
      [%Schema.Item{}, %Schema.Item{}, ...]
  """
  @spec all(Schema.Character.t()) :: [Schema.Item.t()]
  def all(%Schema.Character{id: character_id}) do
    Managers.Inventory.call(character_id, :all)
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
    Managers.Inventory.call(character_id, :list_items)
  end

  @doc """
  Lists all inventory tabs for a character.

  ## Examples

      iex> list_tabs(character)
      [%Schema.InventoryTab{tab: :outfit}, ...]
  """
  @spec list_tabs(Schema.Character.t()) :: [Schema.InventoryTab.t()]
  def list_tabs(%Schema.Character{id: character_id}) do
    Managers.Inventory.call(character_id, :list_tabs)
  end

  @doc """
  Lists items in a specific inventory tab.

  ## Examples

      iex> list_tab_items(character_id, :outfit)
      [%Schema.Item{inventory_tab: :outfit}, ...]
  """
  @spec list_tab_items(integer(), atom()) :: [Schema.Item.t()]
  def list_tab_items(character_id, tab) do
    Managers.Inventory.call(character_id, {:list_tab_items, tab})
  end

  @doc """
  Gets an item by ID for a character.

  ## Examples

      iex> get(character, 123)
      %Schema.Item{}
  """
  @spec get(Schema.Character.t(), integer()) :: Schema.Item.t() | nil
  def get(%{id: char_id}, id) do
    get_by(%{character_id: char_id, id: id})
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
  def add_item(%Schema.Character{} = character, item) do
    result = add_item_result(character, item)
    notify_item_added(character, result)
    result
  end

  defp add_item_result(%Schema.Character{id: character_id}, item) do
    Managers.Inventory.call(character_id, {:add_item, item})
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
  Updates an item with the given attributes.

  ## Examples

      iex> update_item(item, %{amount: 5})
      {:ok, %Schema.Item{amount: 5}}
  """
  @spec update_item(Schema.Item.t() | Ecto.Changeset.t(), map()) ::
          {:ok, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def update_item(%Schema.Item{id: id, character_id: character_id}, attrs) do
    Managers.Inventory.call(character_id, {:update_item, id, attrs})
  end

  def update_item(
        %Ecto.Changeset{data: %Schema.Item{character_id: character_id}} = changeset,
        attrs
      ) do
    Managers.Inventory.call(character_id, {:update_item_changeset, changeset, attrs})
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
  def consume(%Schema.Item{} = item, consumed \\ 1) do
    Managers.Inventory.call(item.character_id, {:consume, item, consumed})
  end

  @doc """
  Consumes an amount of an item across the character's carry stacks,
  deleting stacks emptied by the consumption. Returns per-stack results for
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
  deleting stacks emptied by the consumption. Pairs the inventory cannot
  cover are skipped so callers can keep processing (the completion counter
  no longer matches the live inventory in that case).
  """
  @spec consume_item_amounts(Schema.Character.t(), [map()]) ::
          {:ok, [{:update, Schema.Item.t()} | {:delete, Schema.Item.t()}]}
  def consume_item_amounts(%Schema.Character{id: character_id}, consumables) do
    Managers.Inventory.call(character_id, {:consume_item_amounts, consumables})
  end

  @doc """
  Deletes an item from the inventory.

  ## Examples

      iex> delete(item)
      {:delete, %Schema.Item{}}
  """
  @spec delete(Schema.Item.t()) :: {:delete, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Schema.Item{id: id, character_id: character_id}) do
    Managers.Inventory.call(character_id, {:delete, id})
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

  The scan is bounded by the tab's persisted slot count (base size plus any
  expansions); when every slot is taken it returns `{:error, :full_inventory}`.

  ## Examples

      iex> find_first_available_slot(1, :outfit)
      5

      iex> find_first_available_slot(1, :gear)
      {:error, :full_inventory}
  """
  @spec find_first_available_slot(integer(), atom()) :: integer() | {:error, :full_inventory}
  def find_first_available_slot(character_id, inventory_tab) do
    Managers.Inventory.call(character_id, {:first_available_slot, inventory_tab})
  end

  @doc """
  Counts the free inventory slots in a given tab.

  ## Examples

      iex> free_slot_count(1, :gear)
  """
  @spec free_slot_count(integer(), atom()) :: non_neg_integer()
  def free_slot_count(character_id, inventory_tab) do
    Managers.Inventory.call(character_id, {:free_slot_count, inventory_tab})
  end

  @doc """
  Gets the item in a specific inventory slot.

  ## Examples

      iex> item_in_slot(1, :outfit, 5)
      %Schema.Item{inventory_slot: 5}
  """
  @spec item_in_slot(integer(), atom(), integer()) :: Schema.Item.t() | nil
  def item_in_slot(char_id, tab, slot) do
    Managers.Inventory.call(char_id, {:item_in_slot, tab, slot})
  end

  @doc """
  Swaps an item to a new slot, handling any item that might already be in that slot.

  ## Examples

      iex> swap(item, 10)
      {:ok, 0}
  """
  @spec swap(Schema.Item.t(), integer()) :: {:ok, integer()} | {:error, any()}
  def swap(%Schema.Item{id: id, character_id: character_id}, dst_slot) do
    Managers.Inventory.call(character_id, {:swap, id, dst_slot})
  end

  @doc """
  Expands an inventory tab by adding additional slots.

  ## Examples

      iex> expand_tab(character, :outfit)
      %Schema.InventoryTab{slots: 36}
  """
  @spec expand_tab(Schema.Character.t(), atom()) :: Schema.InventoryTab.t()
  def expand_tab(%Schema.Character{id: character_id}, tab) do
    Managers.Inventory.call(character_id, {:expand_tab, tab})
  end

  @doc """
  Sorts items in a tab by item ID.

  ## Examples

      iex> sort_tab(character, :outfit)
      {:ok, [%Schema.Item{}, ...]}
  """
  @spec sort_tab(Schema.Character.t(), atom()) :: {:ok, [Schema.Item.t()]} | {:error, any()}
  def sort_tab(%Schema.Character{} = character, inventory_tab) do
    Managers.Inventory.call(character.id, {:sort_tab, inventory_tab})
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
