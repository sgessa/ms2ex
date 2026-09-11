defmodule Ms2ex.Managers.Field.Trigger do
  @moduledoc """
  Trigger-script runtime: every map script runs as an independent state
  machine. A machine enters a state (running its on-enter actions), then
  each cycle evaluates the state's conditions in document order — the
  first that evaluates true runs its inline actions and transitions.

  The condition and action catalogs live in `Trigger.Conditions` and
  `Trigger.Actions`.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.Trigger.Actions
  alias Ms2ex.Managers.Field.Trigger.Conditions
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  @tick_ms 100

  # detection boxes grow by 10 units on every axis to compensate for
  # entity size
  @pad 10.0

  # -- setup -----------------------------------------------------------------

  # Every map with trigger scripts runs them: one machine per script,
  # entering its first state on the first tick (on-enter actions, no exit
  # pass). Unimplemented actions warn in the log so coverage gaps surface
  # per map. Maps without scripts keep the empty structures (meshes,
  # cameras, boxes and patrols still load — other systems read them).
  def init_triggers(state) do
    xblock = state.map_id |> Storage.Maps.get_meta() |> Map.get(:x_block)

    state = init_scripts(state, xblock)
    Map.put(state, :script_controlled_npcs, map_size(state.trigger_scripts) > 0)
  end

  defp init_scripts(state, xblock) do
    scripts = Storage.Triggers.get_scripts(xblock)
    meta = Storage.Maps.get_meta(state.map_id)

    trigger_meshes =
      meta
      |> Map.get(:trigger_meshes, [])
      |> Map.new(fn mesh -> {mesh.id, mesh} end)

    trigger_cameras =
      meta
      |> Map.get(:trigger_cameras, [])
      |> Map.new(fn camera -> {camera.id, camera} end)

    trigger_boxes =
      meta
      |> Map.get(:trigger_boxes, [])
      |> Map.new(fn box -> {box.id, box} end)

    patrols =
      meta
      |> Map.get(:patrols, [])
      |> Map.new(fn patrol -> {patrol.name, patrol} end)

    item_spawns =
      meta
      |> Map.get(:item_spawns, [])
      |> Map.new(fn spawn -> {spawn.spawn_point_id, spawn} end)

    trigger_skills =
      meta
      |> Map.get(:trigger_skills, [])
      |> Map.new(fn skill -> {skill.trigger_id, skill} end)

    breakables =
      meta
      |> Map.get(:breakables, [])
      |> Map.new(fn breakable ->
        # the state byte follows the client's breakable table: 2 show, 3
        # broken, 4 hidden
        {breakable.breakable_id, Map.put(breakable, :state, 2)}
      end)

    state
    |> Map.put(:trigger_scripts, scripts)
    |> Map.put(:trigger_meshes, trigger_meshes)
    |> Map.put(:trigger_cameras, trigger_cameras)
    |> Map.put(:trigger_boxes, trigger_boxes)
    |> Map.put(:patrols, patrols)
    |> Map.put(:item_spawns, item_spawns)
    |> Map.put(:trigger_skills, trigger_skills)
    |> Map.put(:breakables, breakables)
    |> Map.put(:user_values, %{})
    |> Map.put(:widgets, %{})
    |> Map.put(:trigger_skips, %{})
    |> init_machines()
  end

  def init_machines(state) do
    machines =
      Map.new(state.trigger_scripts, fn {script_name, script} ->
        {script_name,
         %{
           current: nil,
           next: first_state(script),
           next_tick: now_ms(),
           entered_at: now_ms(),
           skip: nil
         }}
      end)

    Map.put(state, :trigger_machines, machines)
  end

  # -- player tracking ---------------------------------------------------------

  def track_position(state, character_id, position) do
    positions = Map.get(state, :player_positions, %{})

    entry =
      case Map.get(positions, character_id) do
        %{job_code: job_code} -> %{position: position, job_code: job_code}
        _ -> %{position: position, job_code: nil}
      end

    Map.put(state, :player_positions, Map.put(positions, character_id, entry))
  end

  def track_job(state, character_id, job_code) do
    positions = Map.get(state, :player_positions, %{})

    case Map.get(positions, character_id) do
      %{} = entry ->
        Map.put(
          state,
          :player_positions,
          Map.put(positions, character_id, %{entry | job_code: job_code})
        )

      _ ->
        Map.put(
          state,
          :player_positions,
          Map.put(positions, character_id, %{position: nil, job_code: job_code})
        )
    end
  end

  def drop_position(state, character_id) do
    Map.update(state, :player_positions, %{}, &Map.delete(&1, character_id))
  end

  # -- widgets & skips ---------------------------------------------------------

  def update_widget(state, widget_key, arg) do
    conditions =
      state
      |> Map.get(:widgets, %{})
      |> Map.get(widget_key, %{conditions: %{}})
      |> Map.get(:conditions)
      |> Map.put(widget_condition_name(widget_key), arg)

    put_in(state, [:widgets, widget_key, :conditions], conditions)
  end

  defp widget_condition_name(:guide), do: "IsTriggerEvent"
  defp widget_condition_name(:scene_movie), do: "IsStop"
  defp widget_condition_name(_other), do: "Value"

  # the player asked to skip the cutscene (recv TRIGGER cmd 7). A script can
  # arm a skip target with set_skip — jump there directly; otherwise treat
  # the request as a movie stop so the flow's widget condition advances.
  def skip_cutscene(state) do
    skips = Map.get(state, :trigger_skips, %{})

    armed =
      Enum.find(state.trigger_machines, fn {script_name, _machine} ->
        jump_to = Map.get(skips, script_name)
        is_binary(jump_to) and jump_to != ""
      end)

    case armed do
      {script_name, _machine} ->
        state = transition(state, script_name, Map.fetch!(skips, script_name))
        broadcast(state, Packets.Cinematic.start_skip())

      nil ->
        stop_movie(state)
    end
  end

  defp stop_movie(state) do
    widget = get_in(state, [:widgets, :scene_movie])
    movie_id = widget && Map.get(widget, :movie_id)

    if movie_id do
      state = update_widget(state, :scene_movie, movie_id)
      broadcast(state, Packets.Trigger.skip_movie(movie_id))
    else
      state
    end
  end

  defp broadcast(state, packet) do
    Managers.Field.broadcast(state.topic, packet)
    state
  end

  # -- guide holds -------------------------------------------------------------

  # Guide hints are held while the player cannot act on them — a cinematic is
  # running or a scripted path move has the player — and flushed the moment
  # both clear. The follow-dummy notifies the field when its move ends.
  def guide_held?(state),
    do: Map.get(state, :cinematic_on, false) or Map.get(state, :path_move_active, false)

  def release_guide_hold(state) do
    maybe_release_guide_hold(Map.put(state, :path_move_active, false))
  end

  def maybe_release_guide_hold(state) do
    if guide_held?(state) do
      state
    else
      case Map.get(state, :pending_guide) do
        %{entity_id: entity_id, text_id: text_id, duration: duration} ->
          state = Map.put(state, :pending_guide, nil)
          broadcast(state, Packets.Trigger.show_summary(entity_id, text_id, duration))
          state

        _ ->
          state
      end
    end
  end

  # -- machine cycle -----------------------------------------------------------

  def tick(state) do
    now = now_ms()

    state
    |> Map.get(:trigger_machines, %{})
    |> Enum.reduce(state, fn {script_name, machine}, state ->
      if now < machine.next_tick do
        state
      else
        run_machine(script_name, %{machine | next_tick: now + @tick_ms}, now, state)
      end
    end)
  end

  defp run_machine(script_name, machine, now, state) do
    states = state.trigger_scripts[script_name][:states]
    state = put_in(state, [:trigger_machines, script_name], machine)

    case pending_transition(machine) do
      nil ->
        on_tick(script_name, machine, states, now, state)

      next ->
        # leave the current state, enter the next one
        state = run_exit(script_name, states, machine.current, state)
        machine = %{machine | current: next, next: nil, entered_at: now}

        case run_enter(script_name, states, next, state) do
          {nil, state} ->
            # no on-enter transition: conditions run in the same cycle
            state = put_in(state, [:trigger_machines, script_name], machine)
            on_tick(script_name, machine, states, now, state)

          {enter_next, state} ->
            state = put_in(state, [:trigger_machines, script_name], machine)
            transition(state, script_name, enter_next)
        end
    end
  end

  defp pending_transition(machine) do
    if is_binary(machine.next) and machine.next != "", do: machine.next
  end

  defp on_tick(script_name, machine, states, now, state) do
    case states[machine.current] do
      current when is_map(current) ->
        case first_true_condition(current, machine, now, state) do
          nil ->
            state

          {condition, state} ->
            state = Actions.execute_actions(condition[:actions], script_name, state)
            transition(state, script_name, condition[:next_state])
        end

      _ ->
        state
    end
  end

  defp transition(state, _script_name, next_state) when next_state in [nil, ""], do: state

  defp transition(state, script_name, next_state) do
    states = state.trigger_scripts[script_name][:states]

    if is_map_key(states, next_state) do
      put_in(state, [:trigger_machines, script_name, :next], next_state)
    else
      # transition to a filtered-out or unknown state ends the machine
      put_in(state, [:trigger_machines, script_name, :next], nil)
    end
  end

  defp run_enter(script_name, states, state_name, state) do
    case states[state_name] do
      %{} = entry ->
        state = Actions.execute_actions(entry[:on_enter], script_name, state)
        {normalize_next(entry[:next_state]), state}

      _ ->
        {nil, state}
    end
  end

  defp normalize_next(next) when next in [nil, ""], do: nil
  defp normalize_next(next), do: next

  defp run_exit(script_name, states, state_name, state) do
    case states[state_name] do
      %{} = entry -> Actions.execute_actions(entry[:on_exit], script_name, state)
      _ -> state
    end
  end

  defp first_true_condition(current, machine, now, state) do
    current[:conditions]
    |> List.wrap()
    |> Enum.find_value(fn condition ->
      if condition_matches?(condition, machine, now, state), do: {condition, state}
    end)
  end

  defp condition_matches?(condition, machine, now, state) do
    result = Conditions.evaluate(condition[:name], condition[:args] || %{}, machine, now, state)
    if condition[:negate], do: not result, else: result
  end

  # -- geometry ------------------------------------------------------------------

  @doc """
  Whether a position is inside a trigger box; boxes grow by 10 units on
  every axis to compensate for entity size.
  """
  def box_contains?(box, %{x: x, y: y, z: z}) do
    pos = box.position
    dims = box.dimensions

    x >= pos.x - dims.x / 2 - @pad and x <= pos.x + dims.x / 2 + @pad and
      y >= pos.y - dims.y / 2 - @pad and y <= pos.y + dims.y / 2 + @pad and
      z >= pos.z - dims.z / 2 - @pad and z <= pos.z + dims.z / 2 + @pad
  end

  @doc """
  Whether an npc's body capsule overlaps a trigger box: the reference tests
  the box against both the npc's position and its body shape, so a large npc
  (or one riding a mount) registers while its body crosses the box edge even
  when its position point never enters the box.
  """
  def npc_body_in_box?(box, %{npc: npc, position: npc_pos} = _npc_data) do
    capsule = get_in(npc && npc.metadata, [:capsule]) || %{}
    radius = capsule[:radius] || 0
    height = capsule[:height] || 0
    pos = box.position
    dims = box.dimensions

    horizontal? =
      abs(npc_pos.x - pos.x) <= dims.x / 2 + @pad + radius and
        abs(npc_pos.y - pos.y) <= dims.y / 2 + @pad + radius

    z_overlap? =
      npc_pos.z <= pos.z + dims.z / 2 + @pad and
        npc_pos.z + height >= pos.z - dims.z / 2 - @pad

    horizontal? and z_overlap?
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  # scripts declare their execution order; the runtime starts at the first
  defp first_state(%{state_names: [first | _rest]}), do: first
  defp first_state(states), do: states |> Map.keys() |> List.first()
end
