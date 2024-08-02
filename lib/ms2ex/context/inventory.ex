defmodule Ms2ex.Context.Inventory do
  alias __MODULE__.Tab
  alias Ms2ex.{Schema, Repo}

  import Ecto.Query, except: [update: 2]

  def get_by(attrs), do: Repo.get_by(Schema.Item, attrs)

  def all(%Schema.Character{id: character_id}) do
    Schema.Item
    |> where([i], i.character_id == ^character_id)
    |> Repo.all()
  end

  def list_items(%Schema.Character{id: character_id}) do
    Schema.Item
    |> where([i], i.character_id == ^character_id and i.location == ^:inventory)
    |> order_by(asc: :inventory_slot)
    |> Repo.all()
  end

  def list_tabs(%Schema.Character{id: character_id}) do
    Tab
    |> where([i], i.character_id == ^character_id)
    |> order_by(asc: :tab)
    |> Repo.all()
  end

  def list_tab_items(character_id, tab) do
    Schema.Item
    |> where([i], i.character_id == ^character_id)
    |> where([i], i.location == ^:inventory and i.inventory_tab == ^tab)
    |> order_by(asc: :inventory_slot)
    |> Repo.all()
  end

  def get(%{id: char_id}, id) do
    get_by(character_id: char_id, id: id)
  end

  # Item is stackable
  def add_item(%Schema.Character{} = character, %Schema.Item{metadata: %{stack_limit: n}} = attrs)
      when n > 1 do
    Repo.transaction(fn ->
      case find_stack(character, attrs) do
        %Schema.Item{} = item ->
          update_or_create(character, item, attrs)

        nil ->
          create(character, attrs)
      end
    end)
  end

  # Item is not stackable
  def add_item(%Schema.Character{} = character, %Schema.Item{} = attrs) do
    with {:create, item} <- create(character, attrs) do
      {:ok, {:create, item}}
    end
  end

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
         %{amount: amount, stack_limit: stack_limit} = item,
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
    slot = find_first_available_slot(character.id, meta.property.type)

    attrs = %{attrs | inventory_tab: meta.property.type, rarity: rarity, inventory_slot: slot}
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

  def update_item(%Schema.Item{} = item, attrs) do
    item
    |> Schema.Item.changeset(attrs)
    |> Repo.update()
  end

  def consume(item, consumed \\ 1)

  def consume(%Schema.Item{amount: amount} = item, consumed) when amount > consumed do
    update_qty(item, -consumed)
  end

  def consume(%Schema.Item{} = item, _consumed), do: delete(item)

  def delete(%Schema.Item{} = item) do
    with {:ok, item} <- Repo.delete(item) do
      {:delete, item}
    end
  end

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

  def item_in_slot(char_id, tab, slot) do
    Schema.Item
    |> where([i], i.character_id == ^char_id)
    |> where([i], i.inventory_tab == ^tab and i.inventory_slot == ^slot)
    |> limit(1)
    |> Repo.one()
  end

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

  def expand_tab(%Schema.Character{id: character_id}, tab) do
    extra_slots = 6

    Tab
    |> where([i], i.character_id == ^character_id and i.tab == ^tab)
    |> Repo.update_all(inc: [slots: extra_slots])

    Repo.get_by(Tab, character_id: character_id, tab: tab)
  end

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
end
