defmodule Ms2ex.GameHandlers.RequestTutorialItem do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  # the client asks for the starter gear when the job tutorial begins; only
  # level-1 characters on their job's tutorial start field receive it, and
  # only what they do not already hold
  def handle(_packet, session) do
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)
    grant_tutorial_items(character)
    session
  end

  defp grant_tutorial_items(character) do
    with true <- character.level == 1,
         %{start_field: start_field, start_items: start_items} when start_items != [] <-
           Storage.Tables.Jobs.tutorial(character.job),
         true <- character.map_id == start_field do
      Enum.each(start_items, &grant_missing(character, &1))
    else
      _ -> :ok
    end
  end

  defp grant_missing(character, entry) do
    missing = entry.count - owned_count(character, entry.id)

    if missing > 0 do
      grant_units(character, entry, missing)
    end
  end

  # starter gear and consumables are granted one unit at a time, matching
  # how the inventory stacks consumables and keeps gear as separate items
  defp grant_units(character, entry, missing) do
    Enum.each(1..missing, fn _unit ->
      item = Context.Items.init(entry.id, %{amount: 1, rarity: entry.rarity})

      case Managers.Inventory.add_item(character, Context.Items.load_metadata(item)) do
        {:ok, {_status, inventory_item} = result} ->
          push(character, Packets.InventoryItem.add_item(result, character))
          push(character, Packets.InventoryItem.mark_item_new(inventory_item))

        _ ->
          :ok
      end
    end)
  end

  defp owned_count(character, item_id) do
    character
    |> Managers.Inventory.all()
    |> Enum.count(&(&1.item_id == item_id))
  end
end
