defmodule Ms2ex.GameHandlers.NpcTalk do
  @moduledoc """
  NPC interaction flow (talk + quest selection).

  Flow: `Quest.talk` announces the quest list, `NpcTalk.respond` opens the
  dialogue. When the npc offers a quest AND has its own talk script, the
  select script opens the choice menu first (quest vs plain talk); picking
  a side re-enters the dialogue via `NpcTalk.continue` for the quest's
  script state (100s accept / 200s progress / 300s complete) or the npc's
  talk script.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @close 0x00
  @talk 0x01
  @continue 0x02
  @quest 0x07

  # NpcTalkType flags
  @type_dialog 0x01
  @type_talk 0x02
  @type_quest 0x04
  @type_select 0x08

  # quest script state-id bands
  @accept_bounds {100, 199}
  @progress_bounds {200, 299}
  @complete_bounds {300, 399}

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    case command do
      @close ->
        Managers.Character.call(session.character_id, {:set_npc_talk, nil})
        Managers.Shop.clear_active_shop(session.character_id)

      @talk ->
        handle_talk(packet, session)

      @continue ->
        handle_continue(packet, session)

      @quest ->
        handle_quest(packet, session)

      _ ->
        :ok
    end

    :ok
  end

  # Talk: npc interaction entry point. The talk-type flags announce what the
  # npc offers (dialog/shop, quest, talk script, choice menu); the client
  # builds its options from them. Vendor shops open as part of the talk and
  # count as the dialog option.
  defp handle_talk(packet, session) do
    {npc_object_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, field_npc} <- Managers.Field.lookup_npc(character, npc_object_id) do
      talk = gather_talk(character, field_npc)
      route_talk(session, character, npc_object_id, talk)
    else
      _ -> :ok
    end
  end

  defp gather_talk(character, field_npc) do
    npc_id = field_npc.npc.id
    basic = get_in(field_npc.npc.metadata, [:basic]) || %{}
    shop_id = Map.get(basic, :shop_id) || 0
    shop? = shop_id > 0

    Managers.Quest.update_conditions(character.id, :dialogue, 1, "", 0, "", npc_id)
    Managers.Quest.update_conditions(character.id, :talk_in, 1, "", 0, "", npc_id)

    if shop? do
      Managers.Shop.load(character, shop_id, npc_id)
    end

    quests =
      character.id
      |> Managers.Quest.get_available_quests(npc_id)
      |> available_quests()

    quest_talk = first_quest_state(character, quests)
    script_state = npc_script_state(npc_id)
    select_state = npc_select_state(npc_id)

    # the choice menu only appears when the npc offers more than one thing
    options = Enum.count([shop?, quest_talk != nil, script_state != nil], & &1)
    select_menu? = options > 1 and select_state != nil

    %{
      npc_id: npc_id,
      kind: Map.get(basic, :kind) || 0,
      shop?: shop?,
      quests: quests,
      quest_talk: quest_talk,
      script_state: script_state,
      select_state: select_state,
      select_menu?: select_menu?,
      talk_type: talk_type(shop?, quest_talk, script_state, select_menu?)
    }
  end

  defp talk_type(shop?, quest_talk, script_state, select_menu?) do
    [
      {shop?, @type_dialog},
      {quest_talk != nil, @type_quest},
      {script_state != nil, @type_talk},
      {select_menu?, @type_select}
    ]
    |> Enum.reduce(0, fn
      {true, flag}, acc -> acc + flag
      {_false, _flag}, acc -> acc
    end)
  end

  defp route_talk(session, character, npc_object_id, talk) do
    Managers.Character.call(character.id, {:set_npc_talk, nil})

    cond do
      talk.select_menu? ->
        open_choice_menu(
          session,
          character.id,
          npc_object_id,
          talk,
          talk.select_state,
          talk.talk_type
        )

      talk.quest_talk != nil ->
        {_quest_id, state} = talk.quest_talk
        push(session, Packets.Game.Quest.talk(npc_object_id, talk.quests))
        push(session, Packets.NpcTalk.respond(npc_object_id, @type_quest, state))

      talk.script_state == nil and talk.select_state == nil and talk.shop? ->
        # plain vendor: the empty dialog closes immediately, revealing the
        # shop window that was sent with the talk
        push(session, Packets.NpcTalk.respond(npc_object_id, @type_dialog, nil, talk.kind))

      talk.script_state != nil ->
        push(
          session,
          Packets.NpcTalk.respond(npc_object_id, talk.talk_type, talk.script_state, talk.kind)
        )

      talk.select_state != nil ->
        # a select page as the npc's only script: a vendor greeting closes
        # straight into the shop, others offer the selectable talk
        push(
          session,
          Packets.NpcTalk.respond(npc_object_id, talk.talk_type, talk.select_state, talk.kind)
        )

      true ->
        push(session, Packets.NpcTalk.close())
    end
  end

  # the npc offers several things: the select script renders the choice menu
  # (options ordered quests first, then dialog, then talk)
  defp open_choice_menu(session, character_id, npc_object_id, talk, select_state, talk_type) do
    Managers.Character.call(
      character_id,
      {:set_npc_talk, %{npc_id: talk.npc_id, quests: talk.quests, shop?: talk.shop?}}
    )

    if band(talk_type, @type_quest) != 0 do
      push(session, Packets.Game.Quest.talk(npc_object_id, talk.quests))
    end

    push(session, Packets.NpcTalk.respond(npc_object_id, talk_type, select_state))
  end

  # Continue: dialogue advanced ("Next"/pick). With a select menu open the
  # pick routes to the picked quest's script or the npc's talk script.
  # Single-page dialogues only for now; anything further ends the talk so
  # the client never hangs.
  # TODO track per-character script state to walk multi-page dialogues.
  defp handle_continue(packet, session) do
    {pick, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         talk when is_map(talk) <- Map.get(character, :npc_talk) do
      Managers.Character.call(character.id, {:set_npc_talk, nil})
      route_menu_pick(session, character, talk, pick)
    else
      _ -> push(session, Packets.NpcTalk.close())
    end
  end

  # options are ordered quests first, then the vendor dialog, then plain talk
  defp route_menu_pick(session, character, talk, pick) do
    quests = talk.quests

    if pick < length(quests) do
      quest = Enum.fetch!(quests, pick)

      case first_quest_state(character, [quest.id]) do
        nil ->
          push(session, Packets.NpcTalk.close())

        {quest_id, state} ->
          push(session, Packets.NpcTalk.continue(@type_quest, quest_id, state))
      end
    else
      if talk[:shop?] and pick == length(quests) do
        # the dialog pick on a vendor ends the dialogue, revealing the shop
        push(session, Packets.NpcTalk.continue(@type_talk, 0, nil))
      else
        push_talk_script(session, talk.npc_id)
      end
    end
  end

  defp push_talk_script(session, npc_id) do
    case npc_script_state(npc_id) do
      nil -> push(session, Packets.NpcTalk.close())
      state -> push(session, Packets.NpcTalk.continue(@type_talk, 0, state))
    end
  end

  # Quest: a quest was picked from the npc quest list
  defp handle_quest(packet, session) do
    {quest_id, packet} = get_int(packet)
    {_state, _packet} = get_short(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {^quest_id, state} <- first_quest_state(character, [quest_id]) do
      Managers.Character.call(session.character_id, {:set_npc_talk, nil})
      push(session, Packets.NpcTalk.continue(@type_quest, quest_id, state))
    else
      _ -> push(session, Packets.NpcTalk.close())
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

  defp npc_script_state(npc_id) do
    npc_id
    |> Storage.Scripts.get_meta()
    |> Storage.Scripts.states_of_type(:script)
    |> List.first()
  end

  defp band(a, b), do: Bitwise.band(a, b)

  defp npc_select_state(npc_id) do
    npc_id
    |> Storage.Scripts.get_meta()
    |> Storage.Scripts.states_of_type(:select)
    |> List.first()
  end

  defp available_quests(quests) when is_map(quests),
    do: quests |> Map.values() |> Enum.sort_by(& &1.id)

  defp available_quests(quests) when is_list(quests), do: Enum.sort_by(quests, & &1.id)
end
