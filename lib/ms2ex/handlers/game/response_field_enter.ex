defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Context, Enums, Managers, Net, Packets}

  import Net.SenderSession, only: [push: 2, run: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = Managers.Character.lookup(character_id)

    # Check if character is changing map
    character = maybe_change_map(character)
    Managers.Character.update(character)

    run(session, fn -> Context.Field.subscribe(character) end)
    {:ok, _pid} = Context.Field.enter(character)

    # Initialize quest manager and load quests
    start_quest_manager(character.id)
    Managers.Quest.load_quests(session)

    hot_bars = Context.HotBars.list(character)
    push(session, Packets.KeyTable.send_hot_bars(hot_bars))

    favorite_stickers = Context.ChatStickers.list_favorited(character)
    sticker_groups = Context.ChatStickers.list_groups(character)
    push(session, Packets.ChatSticker.load(favorite_stickers, sticker_groups))

    # Update condition for map-related quests
    Managers.Quest.update_conditions(
      character_id,
      Enums.QuestConditionType.all_map(),
      1,
      "",
      character.map_id
    )
  end

  defp maybe_change_map(%{change_map: nil} = character), do: character

  defp maybe_change_map(character) do
    run(character, fn -> Context.Field.unsubscribe(character) end)

    new_map = character.change_map
    {:ok, character} = Context.Characters.update(character, %{map_id: new_map.id})

    character
    |> Map.put(:change_map, nil)
    |> Map.put(:position, new_map.position)
    |> Map.put(:rotation, new_map.rotation)
  end

  defp start_quest_manager(character_id) do
    case Process.whereis(:"quest_manager:#{character_id}") do
      nil -> Managers.Quest.start_link(character_id)
      _ -> :ok
    end
  end
end
