defmodule Ms2ex.GameHandlers.NpcTalk do
  @moduledoc """
  NPC interaction flow (talk + quest selection).

  Flow: `Quest.talk` announces the quest list, `NpcTalk.respond` opens the
  dialogue bound to the npc (first available quest's script state when quests
  exist), and picking a quest from the list re-enters the dialogue via
  `NpcTalk.continue` for that quest's script state (100s accept / 200s
  progress / 300s complete).
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @close 0x00
  @talk 0x01
  @continue 0x02
  @quest 0x07

  @type_quest 0x04

  # quest script state-id bands
  @accept_bounds {100, 199}
  @progress_bounds {200, 299}
  @complete_bounds {300, 399}

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    case command do
      @close -> :ok
      @talk -> handle_talk(packet, session)
      @continue -> handle_continue(packet, session)
      @quest -> handle_quest(packet, session)
      _ -> :ok
    end

    :ok
  end

  # Talk: npc interaction entry point
  defp handle_talk(packet, session) do
    {npc_object_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, field_npc} <- Context.Field.lookup_npc(character, npc_object_id) do
      Managers.Quest.update_conditions(character.id, :dialogue, 1, "", 0, "", field_npc.npc.id)
      Managers.Quest.update_conditions(character.id, :talk_in, 1, "", 0, "", field_npc.npc.id)

      quests =
        character.id
        |> Managers.Quest.get_available_quests(field_npc.npc.id)
        |> available_quests()

      case first_quest_state(character, quests) do
        {_quest_id, state} ->
          push(session, Packets.Game.Quest.talk(npc_object_id, quests))
          push(session, Packets.NpcTalk.respond(npc_object_id, @type_quest, state))

        nil ->
          open_npc_dialogue(session, npc_object_id, field_npc.npc.id)
      end
    else
      _ -> :ok
    end
  end

  # Continue: dialogue advanced ("Next" button). Single-page dialogues only
  # for now; anything further ends the talk so the client never hangs.
  # TODO track per-character script state to walk multi-page dialogues.
  defp handle_continue(_packet, session) do
    push(session, Packets.NpcTalk.close())
  end

  # Quest: a quest was picked from the npc quest list
  defp handle_quest(packet, session) do
    {quest_id, packet} = get_int(packet)
    {_state, _packet} = get_short(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {^quest_id, state} <- first_quest_state(character, [quest_id]) do
      push(session, Packets.NpcTalk.continue(@type_quest, quest_id, state))
    else
      _ -> push(session, Packets.NpcTalk.close())
    end
  end

  defp open_npc_dialogue(session, npc_object_id, npc_id) do
    case first_npc_state(npc_id) do
      nil ->
        push(session, Packets.NpcTalk.close())

      state ->
        push(
          session,
          Packets.NpcTalk.respond(npc_object_id, Packets.NpcTalk.state_talk_type(state), state)
        )
    end
  end

  # Finds the first quest that has a usable script state for the character's
  # progression on it; nil when there are no quests (plain npc talk) or no
  # matching script state. Accepts both metadata maps (quest list) and raw
  # quest ids (quest-pick flow).
  defp first_quest_state(_character, []), do: nil

  defp first_quest_state(character, quests) do
    Enum.find_value(quests, fn quest ->
      quest_id = if is_map(quest), do: quest[:id], else: quest

      with {:ok, bounds} <- selection_bounds(character, quest_id),
           script when not is_nil(script) <- Storage.Scripts.get_meta(quest_id),
           state when not is_nil(state) <- quest_state(script, bounds) do
        {quest_id, state}
      else
        _ -> nil
      end
    end)
  end

  defp selection_bounds(character, quest_id) do
    case Managers.Quest.get_quest(character.id, quest_id) do
      %{state: :started} = quest ->
        if Managers.Quest.Conditions.all_met?(quest) do
          {:ok, @complete_bounds}
        else
          {:ok, @progress_bounds}
        end

      _ ->
        case Storage.Quests.get_meta(quest_id) do
          %{} -> {:ok, @accept_bounds}
          _ -> :error
        end
    end
  end

  defp quest_state(script, {min_id, max_id}) do
    Storage.Scripts.quest_state(script, min_id, max_id)
  end

  defp first_npc_state(npc_id) do
    script = Storage.Scripts.get_meta(npc_id)

    script
    |> Storage.Scripts.states_of_type(:script)
    |> case do
      [] -> script |> Storage.Scripts.states_of_type(:select) |> List.first()
      states -> List.first(states)
    end
  end

  defp available_quests(quests) when is_map(quests),
    do: quests |> Map.values() |> Enum.sort_by(& &1.id)

  defp available_quests(quests) when is_list(quests), do: Enum.sort_by(quests, & &1.id)
end
