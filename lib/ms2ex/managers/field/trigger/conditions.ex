defmodule Ms2ex.Managers.Field.Trigger.Conditions do
  @moduledoc """
  Trigger-script condition catalog. A condition evaluates against the
  machine's state and the field state; the runtime runs the first
  condition that returns true.
  """

  import Ms2ex.Helpers.TriggerArgs

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.Trigger

  # true when a player standing in one of the boxes has the quest in the
  # wanted state (1 = started; 2/3 = finished in ms2ex's simpler model)
  def evaluate("always", _args, _machine, _now, _state), do: true

  # wait_tick compares against the state's entry tick; the script arg is
  # the named waitTick value, not a positional arg
  def evaluate("wait_tick", args, machine, now, _state),
    do: now > machine.entered_at + int_arg(args, :wait_tick)

  def evaluate("user_detected", args, _machine, _now, state) do
    box_ids = int_list_arg(args, :box_ids)
    job_code = int_arg(args, :job_code)
    boxes = Enum.filter(Map.values(Map.get(state, :trigger_boxes, %{})), &(&1.id in box_ids))

    state
    |> Map.get(:player_positions, %{})
    |> Map.values()
    |> Enum.any?(fn
      %{position: %{} = position, job_code: code} ->
        (job_code == 0 or code == job_code) and
          Enum.any?(boxes, &Trigger.box_contains?(&1, position))

      _ ->
        false
    end)
  end

  def evaluate("monster_dead", args, _machine, _now, state) do
    spawn_point_ids = int_list_arg(args, :spawn_ids)

    state.npc_spawns
    |> Map.values()
    |> Enum.filter(&(&1[:spawn_point_id] in spawn_point_ids))
    |> Enum.all?(&spawn_wiped?(state, &1))
  end

  # true when a story npc (matched by spawn point, not object id — a spawn
  # can be refilled/replaced) is currently standing inside the box. Drives
  # scripted arrivals (e.g. an npc walking off through move_npc reaching its
  # destination) rather than player detection
  def evaluate("npc_detected", args, _machine, _now, state) do
    spawn_point_ids = int_list_arg(args, :spawn_ids)

    case Map.get(state.trigger_boxes, int_arg(args, :box_id)) do
      nil ->
        false

      box ->
        state.npcs
        |> Map.values()
        |> Enum.any?(fn npc ->
          npc.spawn_point_id in spawn_point_ids and Trigger.box_contains?(box, npc.position)
        end)
    end
  end

  # matches when the script previously stored this value under the key via
  # set_user_value
  def evaluate("user_value", args, _machine, _now, state) do
    key = to_string(args[:key] || "")
    Map.get(Map.get(state, :user_values, %{}), key) == int_arg(args, :value)
  end

  # true when one of the interact objects (matched by its table id) currently
  # sits in the wanted state (0 normal, 1 reactable, 2 hidden) — e.g. the
  # tutorial car the moment the player boards it
  def evaluate("object_interacted", args, _machine, _now, state) do
    interact_ids = int_list_arg(args, :interact_ids)
    wanted = int_arg(args, :state)

    state
    |> Map.get(:interactable, %{})
    |> Map.values()
    |> Enum.any?(&(&1.id in interact_ids and interact_state_code(&1.state) == wanted))
  end

  def evaluate("widget_condition", args, _machine, _now, state) do
    conditions = get_in(state, [:widgets, widget_key(args[:type]), :conditions]) || %{}
    value = Map.get(conditions, args[:widget_name])
    value != nil and value == int_arg(args, :condition)
  end

  def evaluate("quest_user_detected", args, _machine, _now, state) do
    box_ids = int_list_arg(args, :box_ids)
    quest_id = int_arg(args, :quest_ids)
    wanted = int_arg(args, :quest_states)
    boxes = Enum.filter(Map.values(Map.get(state, :trigger_boxes, %{})), &(&1.id in box_ids))

    Enum.any?(state.player_positions, fn {character_id, %{position: position}} ->
      is_map(position) and Enum.any?(boxes, &Trigger.box_contains?(&1, position)) and
        quest_state_is?(character_id, quest_id, wanted)
    end)
  end

  def evaluate(_name, _args, _machine, _now, _state), do: false

  # the wanted-state semantics: 1 = started (but not completable),
  # 2 = started with all conditions met (completable), 3 = completed
  @spec quest_state_matches?(map() | nil, integer()) :: boolean()
  def quest_state_matches?(nil, _wanted), do: false

  def quest_state_matches?(quest, wanted) do
    started? = quest.state == :started

    cond do
      wanted == 1 -> started? and not Managers.Quest.Conditions.all_met?(quest)
      wanted == 2 -> started? and Managers.Quest.Conditions.all_met?(quest)
      wanted == 3 -> quest.state == :completed
      true -> false
    end
  end

  defp quest_state_is?(character_id, quest_id, wanted) do
    quest = Managers.Quest.get_quest(character_id, quest_id)
    quest_state_matches?(quest, wanted)
  catch
    _kind, _reason -> false
  end

  defp spawn_wiped?(state, spawn) do
    Enum.all?(spawn.spawned_mobs, fn object_id ->
      case Map.get(state.npcs, object_id) do
        %{dead?: dead?} -> dead?
        _ -> true
      end
    end)
  end

  defp interact_state_code(:reactable), do: 1
  defp interact_state_code(:hidden), do: 2
  defp interact_state_code(_state), do: 0
end
