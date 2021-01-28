defmodule Ms2ex.Inventory do
  alias __MODULE__.Item
  alias Ms2ex.{Character, Metadata, Repo}

  import Ecto.Query, except: [update: 2]

  def get_by(attrs), do: Repo.get_by(Item, attrs)

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

  defp create(character, %{amount: n} = attrs) when n > 0 do
    attrs = Map.from_struct(attrs)

    changeset =
      character
      |> Ecto.build_assoc(:inventory_items)
      |> Item.changeset(attrs)

    with {:ok, item} <- Repo.insert(changeset) do
      {:create, Metadata.Items.load(item)}
    end
  end

  defp create(_character, _attrs), do: :nothing

  defp update(%{id: id}, new_amount) do
    Item
    |> where([i], i.id == ^id)
    |> Repo.update_all(inc: [amount: new_amount])

    item = Item |> Repo.get(id) |> Metadata.Items.load()
    {:update, item, new_amount}
  end

  def slot_value(%Item{metadata: %{slot: slot}}), do: Metadata.ItemSlot.value(slot)

  def equip(%Item{location: :inventory} = item) do
    update_item(item, %{location: :equipment})
  end

  def unequip(character_id, id) do
    with %Item{location: :equipment} = item <- get_by(character_id: character_id, id: id),
         {:ok, item} <- update_item(item, %{location: :inventory}) do
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
end
