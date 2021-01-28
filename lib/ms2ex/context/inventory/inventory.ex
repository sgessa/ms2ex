defmodule Ms2ex.Inventory do
  alias __MODULE__.Item
  alias Ms2ex.{Character, Repo}

  import Ecto.Query, except: [update: 2]

  def get_by(attrs), do: Repo.get_by(Item, attrs)

  def list_items(%Character{id: char_id}) do
    Item
    |> where([i], i.character_id == ^char_id and i.location == ^:inventory)
    |> Repo.all()
  end

  def add_item(%Character{} = character, %Item{metadata: %{max_slot: n}} = attrs) when n > 1 do
    Repo.transaction(fn ->
      case find_item(character, attrs) do
        %Item{} = item ->
          update_or_create(character, item, attrs)

        nil ->
          create(character, attrs)
      end
    end)
  end

  def add_item(%Character{} = character, %Item{} = attrs) do
    with {:create, item} <- create(character, attrs) do
      {:ok, {:create, item}}
    end
  end

  defp find_item(%{id: char_id}, %{item_id: item_id, max_slot: max_slot}) do
    Item
    |> where([i], i.character_id == ^char_id)
    |> where([i], i.item_id == ^item_id and i.amount < ^max_slot)
    |> limit(1)
    |> Repo.one()
  end

  defp update_or_create(
         character,
         %{amount: amount, max_slot: max_slot} = item,
         %{amount: new_amount} = attrs
       )
       when amount + new_amount > max_slot do
    amount_added = max_slot - amount
    amount_created = new_amount - amount_added
    attrs = %{attrs | amount: amount_created}

    with {:update, updated, new_amount} <- update(item, amount_added),
         {:create, created} <- create(character, attrs) do
      {:update_and_create, {updated, new_amount}, created}
    end
  end

  defp update_or_create(_character, item, %{amount: new_amount}) do
    update(item, new_amount)
  end

  defp create(character, %{amount: n, metadata: meta} = attrs) when n > 0 do
    attrs = Map.put(attrs, :inventory_tab, meta.tab)
    attrs = Map.from_struct(attrs)

    changeset =
      character
      |> Ecto.build_assoc(:inventory_items)
      |> Item.changeset(attrs)

    with {:ok, item} <- Repo.insert(changeset) do
      {:create, %{item | metadata: meta}}
    end
  end

  defp create(_character, _attrs), do: :nothing

  defp update(%{id: id, metadata: meta}, new_amount) do
    Item
    |> where([i], i.id == ^id)
    |> Repo.update_all(inc: [amount: new_amount])

    item = Item |> Repo.get(id) |> Map.put(:metadata, meta)
    {:update, item, new_amount}
  end

  def equip(%Item{location: :inventory} = item) do
    update_item(item, %{location: :equipment})
  end

  def unequip(%Character{} = character, id) do
    with %Item{location: :equipment} = item <- get_by(character_id: character.id, id: id),
         slot <- determine_inventory_slot(item),
         {:ok, item} <- update_item(item, %{location: :inventory, inventory_slot: slot}) do
      {:ok, item}
    else
      %Item{location: :inventory} ->
        {:error, :item_not_equipped}

      nil ->
        {:error, :item_not_found}
    end
  end

  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  def determine_inventory_slot(%Item{inventory_slot: -1}), do: -1

  def determine_inventory_slot(%Item{} = item) do
    if item_in_slot(item.character_id, item.inventory_tab, item.inventory_slot) do
      -1
    else
      item.inventory_slot
    end
  end

  def item_in_slot(char_id, tab, slot) do
    Item
    |> where([i], i.character_id == ^char_id)
    |> where([i], i.inventory_tab == ^tab and i.inventory_slot == ^slot)
    |> limit(1)
    |> Repo.one()
  end
end
