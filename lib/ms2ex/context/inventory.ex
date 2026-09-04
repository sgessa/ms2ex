defmodule Ms2ex.Context.Inventory do
  @moduledoc """
  Item persistence helpers.

  Reads load the rows a manager needs to build its state, and writes
  persist the mutations a manager has already applied to memory. All the
  gameplay flows go through `Ms2ex.Managers.Inventory`; this module is its
  database layer. The one flow that runs before any session exists —
  character creation — inserts its starting outfit here directly.
  """

  import Ecto.Query, except: [update: 2]

  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  # ---- reads ----

  @doc """
  Lists every item row of a character (equipped and carried).
  """
  @spec list_items(integer()) :: [Schema.Item.t()]
  def list_items(character_id) do
    Schema.Item
    |> where([i], i.character_id == ^character_id)
    |> Repo.all()
  end

  @doc """
  Lists a character's inventory tab rows.
  """
  @spec list_tabs(integer()) :: [Schema.InventoryTab.t()]
  def list_tabs(character_id) do
    Schema.InventoryTab
    |> where([t], t.character_id == ^character_id)
    |> order_by(asc: :tab)
    |> Repo.all()
  end

  @doc """
  Lists a character's equipped item rows.
  """
  @spec list_equipped(integer()) :: [Schema.Item.t()]
  def list_equipped(character_id) do
    Schema.Item
    |> where([i], i.character_id == ^character_id and i.location == ^:equipment)
    |> Repo.all()
  end

  # ---- writes ----

  @doc """
  Inserts a new item row. The attributes must already carry the inventory
  tab, slot and rarity; the tab is derived from the item's metadata when
  not given.
  """
  @spec insert_item(integer(), Schema.Item.t() | map()) ::
          {:ok, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def insert_item(character_id, %{metadata: meta} = attrs) do
    rarity = Map.get(attrs, :rarity) || 1
    inventory_tab = Map.get(attrs, :inventory_tab) || Types.Item.inventory_tab(meta)

    item_attrs =
      attrs
      |> Map.put(:inventory_tab, inventory_tab)
      |> Map.put(:rarity, rarity)
      |> Map.from_struct()

    changeset =
      %Schema.Character{id: character_id}
      |> Ecto.build_assoc(:inventory_items)
      |> Schema.Item.changeset(item_attrs)

    with {:ok, item} <- Repo.insert(changeset) do
      {:ok, %{item | metadata: meta}}
    end
  end

  @doc """
  Updates an item row from a struct or changeset plus attributes.
  """
  @spec update_item(Schema.Item.t() | Ecto.Changeset.t(), map()) ::
          {:ok, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def update_item(%Schema.Item{} = item, attrs) do
    item
    |> Schema.Item.changeset(attrs)
    |> Repo.update()
  end

  def update_item(%Ecto.Changeset{} = changeset, attrs) do
    changeset
    |> Schema.Item.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Adds a delta to an item's amount.
  """
  @spec update_amount(integer(), integer()) :: :ok
  def update_amount(item_id, delta) do
    from(i in Schema.Item, where: i.id == ^item_id)
    |> Repo.update_all(inc: [amount: delta])

    :ok
  end

  @doc """
  Overwrites an item's amount.
  """
  @spec set_amount(integer(), integer()) :: :ok
  def set_amount(item_id, amount) do
    from(i in Schema.Item, where: i.id == ^item_id)
    |> Repo.update_all(set: [amount: amount])

    :ok
  end

  @doc """
  Deletes an item row.
  """
  @spec delete_item(Schema.Item.t()) :: {:ok, Schema.Item.t()} | {:error, Ecto.Changeset.t()}
  def delete_item(%Schema.Item{} = item), do: Repo.delete(item)

  @doc """
  Deletes item rows by id.
  """
  @spec delete_items([integer()]) :: :ok
  def delete_items(ids) do
    from(i in Schema.Item, where: i.id in ^ids)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Clears the inventory slot of the given items (making them sortable).
  """
  @spec clear_slots([integer()]) :: :ok
  def clear_slots(item_ids) do
    from(i in Schema.Item, where: i.id in ^item_ids)
    |> Repo.update_all(set: [inventory_slot: nil])

    :ok
  end

  @doc """
  Writes an item's inventory slot.
  """
  @spec assign_slot(integer(), integer() | nil) :: :ok
  def assign_slot(item_id, slot) do
    from(i in Schema.Item, where: i.id == ^item_id)
    |> Repo.update_all(set: [inventory_slot: slot])

    :ok
  end

  @doc """
  Adds extra slots to an inventory tab row.
  """
  @spec expand_tab(integer(), integer()) :: :ok
  def expand_tab(tab_id, extra_slots) do
    from(t in Schema.InventoryTab, where: t.id == ^tab_id)
    |> Repo.update_all(inc: [slots: extra_slots])

    :ok
  end
end
