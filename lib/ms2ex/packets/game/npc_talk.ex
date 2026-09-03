defmodule Ms2ex.Packets.NpcTalk do
  @moduledoc """
  NpcTalk packet builders.

  Dialogue frames carry `(state_id, index, button)`; the client renders the
  dialogue text from its own script data for that state id + index.
  """

  import Ms2ex.Packets.PacketWriter

  @close 0x00
  @respond 0x01
  @continue 0x02
  @update 0x04

  # NpcTalkType flags
  @type_talk 0x02
  @type_select 0x08

  # NpcTalkButton values
  @button_none 0x00
  @button_close 0x03
  @button_quest_accept 0x06
  @button_quest_complete 0x07
  @button_quest_progress 0x08
  @button_selectable_distractor 0x09

  def close do
    __MODULE__
    |> build()
    |> put_byte(@close)
  end

  # Respond(npcObjectId, talkType, dialogue): opens the talk UI on an npc
  def respond(object_id, talk_type, state) do
    {state_id, index, button} = dialogue(state)

    __MODULE__
    |> build()
    |> put_byte(@respond)
    |> put_int(object_id)
    |> put_byte(talk_type)
    |> put_int(state_id)
    |> put_int(index)
    |> put_int(button)
  end

  # Continue(talkType, questId, dialogue): re-enters the talk for a quest
  def continue(talk_type, quest_id, state) do
    {state_id, index, button} = dialogue(state)

    __MODULE__
    |> build()
    |> put_byte(@continue)
    |> put_byte(talk_type)
    |> put_int(quest_id)
    |> put_int(state_id)
    |> put_int(index)
    |> put_int(button)
  end

  # Update(text, voiceId, illust): cinematic/event script text
  def update(text, voice_id \\ "", illust \\ "") do
    __MODULE__
    |> build()
    |> put_byte(@update)
    |> put_ustring(text)
    |> put_ustring(voice_id)
    |> put_ustring(illust)
  end

  @doc "Talk-type flag for a script state (:script -> talk, :select -> select)."
  def state_talk_type(%{type: :select}), do: @type_select
  def state_talk_type(_state), do: @type_talk

  defp dialogue(%{} = state) do
    {state[:id] || 0, 0, button(state)}
  end

  defp dialogue(nil), do: {0, 0, @button_none}

  # Dialogue buttons: an explicit content button wins, distractor pages
  # normally offer selectable options, and quest states resolve to their
  # state-band button (100s accept / 200s progress / 300s complete). Quest
  # scripts frequently carry distractor pages we don't walk yet; offering
  # dialogue choices instead of Accept/Complete would strand the
  # conversation, so the band button always wins for quest states.
  defp button(state) do
    case state do
      %{type: :quest, id: id} when is_integer(id) ->
        quest_band_button(id)

      %{contents: [content | _]} ->
        cond do
          content[:button_type] not in [nil, 0] -> content.button_type
          distractors?(content) -> @button_selectable_distractor
          true -> @button_close
        end

      _ ->
        @button_close
    end
  end

  defp quest_band_button(id) do
    case div(id, 100) do
      1 -> @button_quest_accept
      2 -> @button_quest_progress
      3 -> @button_quest_complete
      _ -> @button_close
    end
  end

  defp distractors?(%{distractors: distractors}) when is_list(distractors),
    do: distractors != []

  defp distractors?(_content), do: false
end
