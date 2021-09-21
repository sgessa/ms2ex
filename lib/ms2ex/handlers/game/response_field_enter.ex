defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Characters, ChatStickers, Field, HotBars, Net, Packets, World}

  import Net.Session, only: [push: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = World.get_character(character_id)

    # Check if character is changing map
    character = maybe_change_map(character)
    World.update_character(character)

    Field.subscribe(character)
    {:ok, _pid} = Field.enter(character)

    hot_bars = HotBars.list(character)

    favorite_stickers = ChatStickers.list_favorited(character)
    sticker_groups = ChatStickers.list_groups(character)

    session
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
    |> push(Packets.ChatSticker.load(favorite_stickers, sticker_groups))
  end

  defp maybe_change_map(%{change_map: new_map} = character) do
    Field.unsubscribe(character)
    {:ok, character} = Characters.update(character, %{map_id: new_map.id})

    character
    |> Map.delete(:change_map)
    |> Map.put(:position, new_map.position)
    |> Map.put(:rotation, new_map.rotation)
  end

  defp maybe_change_map(character), do: character
end
