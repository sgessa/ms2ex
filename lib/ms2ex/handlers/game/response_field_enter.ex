defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Net.SenderSession, only: [push: 2, run: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = Managers.Character.call(character_id, :lookup)

    # Check if character is changing map
    character = maybe_change_map(character)
    Managers.Character.call(character, {:update, character})

    run(session, fn -> Context.Field.subscribe(character) end)
    {:ok, _pid} = Context.Field.enter(character)

    case start_quest_manager(character.id) do
      {:ok, _pid} -> Managers.Quest.load_quests(session)
      :ok -> :ok
    end

    hot_bars = Context.HotBars.list(character)
    push(session, Packets.KeyTable.send_hot_bars(hot_bars))

    send_skill_cooldowns(session, character_id)

    favorite_stickers = Context.ChatStickers.list_favorited(character)
    sticker_groups = Context.ChatStickers.list_groups(character)
    push(session, Packets.ChatSticker.load(favorite_stickers, sticker_groups))

    continent = Storage.Maps.get_property(character.map_id) |> Map.get(:continent, 0)

    Managers.Quest.update_conditions(character_id, :map, 1, "", 0, "", character.map_id)
    Managers.Quest.update_conditions(character_id, :explore, 1, "", 0, "", character.map_id)
    Managers.Quest.update_conditions(character_id, :continent, 1, "", 0, "", continent)
    Managers.Quest.update_conditions(character_id, :explore_continent, 1, "", 0, "", continent)
  end

  defp send_skill_cooldowns(session, character_id) do
    case Managers.Character.call(character_id, {:get_skill_cooldowns, Ms2ex.sync_ticks()}) do
      {:ok, []} -> :ok
      {:ok, cooldowns} -> push(session, Packets.SkillCooldown.bytes(cooldowns))
      :error -> :ok
    end
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
      nil -> Managers.Quest.start(character_id)
      _ -> :ok
    end
  end
end
