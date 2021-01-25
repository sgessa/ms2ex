defmodule Ms2ex.Inventory do
  alias __MODULE__.Item
  alias Ms2ex.{Repo, Character}
  alias Ms2ex.Protobuf.{ItemMetadata, ItemSlot}

  import Ecto.Query, except: [update: 2]

  def load_metadata(%Item{} = item) do
    case :ets.lookup(:metadata, item.item_id) do
      [{_id, %ItemMetadata{} = meta}] -> %{item | metadata: meta}
      _ -> item
    end
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

  defp create(character, %{amount: n} = attrs) when n > 0 do
    attrs = Map.from_struct(attrs)

    changeset =
      character
      |> Ecto.build_assoc(:inventory_items)
      |> Item.changeset(attrs)

    with {:ok, item} <- Repo.insert(changeset) do
      {:create, load_metadata(item)}
    end
  end

  defp create(_character, _attrs), do: :nothing

  defp update(%{id: id}, new_amount) do
    Item
    |> where([i], i.id == ^id)
    |> Repo.update_all(inc: [amount: new_amount])

    item = Item |> Repo.get(id) |> load_metadata()
    {:update, item, new_amount}
  end

  def load_equips(%Character{id: char_id} = char) do
    equips =
      Item
      |> where([i], i.character_id == ^char_id)
      |> Repo.all()
      |> Enum.map(fn item -> load_metadata(item) end)

    Map.put(char, :equips, equips)
  end

  def slot_value(%Item{metadata: %{slot: slot}}), do: ItemSlot.value(slot)
end
