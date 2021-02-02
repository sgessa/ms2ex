defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Characters, Field, HotBars, Inventory, Metadata, Net, Packets, Registries}

  import Net.SessionHandler, only: [push: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = Registries.Characters.lookup(character_id)

    # Check if character is changing map
    character = maybe_change_map(character)

    {:ok, _pid} = Field.enter(character, session)

    items = Inventory.list_items(character)

    session =
      Enum.reduce(items, session, fn item, session ->
        item = Metadata.Items.load(item)
        push(session, Packets.InventoryItem.add_item({:create, item}))
      end)

    hot_bars = HotBars.list(character)

    session
    # |> push(Packets.StatPoints.bytes(character))
    # |> push(Packets.Emotion.bytes())
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  def maybe_change_map(%{change_map: new_map} = character) do
    # Save Map ID on the database
    {:ok, character} = Characters.update(character, %{map_id: new_map.id})

    character
    |> Map.delete(:change_map)
    |> Map.put(:position, new_map.position)
    |> Map.put(:rotation, new_map.rotation)
    |> Registries.Characters.update()
  end

  def maybe_change_map(character), do: character
end
