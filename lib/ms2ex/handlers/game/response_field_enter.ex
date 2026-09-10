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
    character = Managers.Field.assign_instance(character)
    Managers.Character.call(character, {:update, character})

    run(session, fn -> Managers.Field.subscribe(character) end)

    hot_bars = Context.HotBars.list(character)

    # a fresh character has no saved quick-slot layout: fill the active hot
    # bar with the job's learned active skills, send the hot bars, then let
    # the client apply its own key-bind defaults (LoadDefault). both must
    # precede the field-enter stream so the client initializes its ui from
    # them
    hot_bars =
      if fresh_hot_bars?(hot_bars) do
        Context.HotBars.update_hotbar_skills(character, hot_bars)
      else
        hot_bars
      end

    push(session, Packets.KeyTable.send_hot_bars(hot_bars))

    if fresh_hot_bars?(hot_bars) do
      push(session, Packets.KeyTable.request())
    end

    push(session, Packets.GuideRecord.load(character.guide_records))

    {:ok, _pid} = Managers.Field.enter(character)

    case start_quest_manager(character.id) do
      {:ok, _pid} -> Managers.Quest.load_quests(session)
      :ok -> :ok
    end

    send_skill_cooldowns(session, character_id)

    favorite_stickers = Context.ChatStickers.list_favorited(character)
    sticker_groups = Context.ChatStickers.list_groups(character)
    push(session, Packets.ChatSticker.load(favorite_stickers, sticker_groups))

    Managers.GuildServer.call(
      character.guild_id,
      {:update_member_map, character.id, character.map_id, character.field_instance}
    )

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
    run(character, fn -> Managers.Field.unsubscribe(character) end)

    new_map = character.change_map
    character = persist_current_map(character, new_map)

    # the safe position has to follow the map: out-of-bounds recovery teleports
    # to it, and a coordinate from the previous map is out of bounds here too
    character
    |> Map.put(:change_map, nil)
    |> Map.put(:field_instance, new_map.instance)
    |> Map.put(:position, new_map.position)
    |> Map.put(:safe_position, new_map.position)
    |> Map.put(:rotation, new_map.rotation)
  end

  # the persisted map is the map's enter_return_id when it declares one
  # (a relog inside a quest instance lands at its hub); the in-memory map
  # id follows the actual map — the field process is built from it
  defp persist_current_map(character, new_map) do
    {:ok, character} =
      Context.Characters.update(character, %{map_id: Managers.Field.return_map_id(new_map.id)})

    Map.put(character, :map_id, new_map.id)
  end

  defp start_quest_manager(character_id) do
    case Process.whereis(:"quest_manager:#{character_id}") do
      nil -> Managers.Quest.start_link(character_id)
      _ -> :ok
    end
  end

  defp fresh_hot_bars?(hot_bars) do
    Enum.all?(hot_bars, fn hot_bar ->
      Enum.all?(hot_bar.quick_slots, &(&1.skill_id in [nil, 0]))
    end)
  end
end
