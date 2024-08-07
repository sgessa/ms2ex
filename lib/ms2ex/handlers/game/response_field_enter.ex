defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Managers, Context, Context, Net, Packets}

  import Net.SenderSession, only: [push: 2, run: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = Managers.Character.lookup(character_id)

    # Check if character is changing map
    character = maybe_change_map(character)
    Managers.Character.update(character)

    run(session, fn -> Context.Field.subscribe(character) end)
    {:ok, _pid} = Context.Field.enter(character)

    hot_bars = Context.HotBars.list(character)
    push(session, Packets.KeyTable.send_hot_bars(hot_bars))

    favorite_stickers = Context.ChatStickers.list_favorited(character)
    sticker_groups = Context.ChatStickers.list_groups(character)
    push(session, Packets.ChatSticker.load(favorite_stickers, sticker_groups))
  end

  defp maybe_change_map(%{change_map: new_map} = character) do
    run(character, fn -> Context.Field.unsubscribe(character) end)

    {:ok, character} = Context.Characters.update(character, %{map_id: new_map.id})

    character
    |> Map.delete(:change_map)
    |> Map.put(:position, new_map.position)
    |> Map.put(:rotation, new_map.rotation)
  end

  defp maybe_change_map(character), do: character
end
