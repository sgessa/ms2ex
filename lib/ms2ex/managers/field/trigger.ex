defmodule Ms2ex.Managers.Field.Trigger do
  @moduledoc """
  Trigger-script runtime: every map script runs as an independent state
  machine. A machine enters a state (running its on-enter actions), then
  each cycle evaluates the state's conditions in document order — the
  first that evaluates true runs its inline actions and transitions.

  Function arguments arrive verbatim from the client data (positional
  arg1..N or named); their meaning follows each function's catalog
  signature.
  """

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field
  alias Ms2ex.Navigation
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types.FieldNpc

  @tick_ms 100

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

    state
    |> Map.put(:trigger_scripts, scripts)
    |> Map.put(:trigger_meshes, trigger_meshes)
    |> Map.put(:trigger_cameras, trigger_cameras)
    |> Map.put(:trigger_boxes, trigger_boxes)
    |> Map.put(:patrols, patrols)
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
        state
        |> transition(script_name, Map.fetch!(skips, script_name))
        |> broadcast(Packets.Cinematic.start_skip())

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
    Context.Field.broadcast(state.topic, packet)
    state
  end

  # -- machine cycle ---------------------------------------------------------

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
            state = execute_actions(condition[:actions], script_name, state)
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
        state = execute_actions(entry[:on_enter], script_name, state)
        {normalize_next(entry[:next_state]), state}

      _ ->
        {nil, state}
    end
  end

  defp normalize_next(next) when next in [nil, ""], do: nil
  defp normalize_next(next), do: next

  defp run_exit(script_name, states, state_name, state) do
    case states[state_name] do
      %{} = entry -> execute_actions(entry[:on_exit], script_name, state)
      _ -> state
    end
  end

  # -- conditions ------------------------------------------------------------

  defp first_true_condition(current, machine, now, state) do
    current[:conditions]
    |> List.wrap()
    |> Enum.find_value(fn condition ->
      if condition_matches?(condition, machine, now, state), do: {condition, state}
    end)
  end

  defp condition_matches?(condition, machine, now, state) do
    result = evaluate(condition[:name], condition[:args] || %{}, machine, now, state)
    if condition[:negate], do: not result, else: result
  end

  defp evaluate("always", _args, _machine, _now, _state), do: true

  # wait_tick compares against the state's entry tick; the script arg is
  # the named waitTick value, not a positional arg
  defp evaluate("wait_tick", args, machine, now, _state),
    do: now > machine.entered_at + int_arg(args, :wait_tick)

  defp evaluate("user_detected", args, _machine, _now, state) do
    box_ids = int_list_arg(args, :box_ids)
    job_code = int_arg(args, :job_code)
    boxes = Enum.filter(Map.values(Map.get(state, :trigger_boxes, %{})), &(&1.id in box_ids))

    state
    |> Map.get(:player_positions, %{})
    |> Map.values()
    |> Enum.any?(fn
      %{position: %{} = position, job_code: code} ->
        (job_code == 0 or code == job_code) and Enum.any?(boxes, &box_contains?(&1, position))

      _ ->
        false
    end)
  end

  defp evaluate("monster_dead", args, _machine, _now, state) do
    spawn_point_ids = int_list_arg(args, :spawn_ids)

    state.npc_spawns
    |> Map.values()
    |> Enum.filter(&(&1[:spawn_point_id] in spawn_point_ids))
    |> Enum.all?(&spawn_wiped?(state, &1))
  end

  defp evaluate("widget_condition", args, _machine, _now, state) do
    conditions = get_in(state, [:widgets, widget_key(args[:type]), :conditions]) || %{}
    value = Map.get(conditions, args[:widget_name])
    value != nil and value == int_arg(args, :condition)
  end

  # true when a player standing in one of the boxes has the quest in the
  # wanted state (1 = started; 2/3 = finished in ms2ex's simpler model)
  defp evaluate("quest_user_detected", args, _machine, _now, state) do
    box_ids = int_list_arg(args, :box_ids)
    quest_id = int_arg(args, :quest_ids)
    wanted = int_arg(args, :quest_states)
    boxes = Enum.filter(Map.values(Map.get(state, :trigger_boxes, %{})), &(&1.id in box_ids))

    Enum.any?(state.player_positions, fn {character_id, %{position: position}} ->
      is_map(position) and Enum.any?(boxes, &box_contains?(&1, position)) and
        quest_state_is?(character_id, quest_id, wanted)
    end)
  end

  defp evaluate(_name, _args, _machine, _now, _state), do: false

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

  # -- actions ---------------------------------------------------------------

  defp execute_actions(actions, script_name, state) when is_list(actions) do
    Enum.reduce(actions, state, fn action, state ->
      execute_action(action[:name], action[:args] || %{}, script_name, state)
    end)
  end

  defp execute_actions(_actions, _script_name, state), do: state

  defp execute_action("set_mesh", args, _script_name, state) do
    visible = bool_arg(args, :visible)
    meshes = Map.get(state, :trigger_meshes, %{})

    Enum.reduce(int_list_arg(args, :trigger_ids), state, fn mesh_id, state ->
      case Map.get(meshes, mesh_id) do
        %{} = mesh ->
          Context.Field.broadcast(state.topic, Packets.Trigger.update_mesh(visible, mesh))
          state

        _ ->
          state
      end
    end)
  end

  defp execute_action("set_portal", args, _script_name, state),
    do: update_portal(int_arg(args, :portal_id), args, state)

  defp execute_action("guide_event", args, _script_name, state) do
    Context.Field.broadcast(state.topic, Packets.Trigger.guide_event(int_arg(args, :event_id)))
    state
  end

  defp execute_action("spawn_monster", args, _script_name, state) do
    Enum.reduce(int_list_arg(args, :spawn_ids), state, fn spawn_point_id, state ->
      Field.Npc.trigger_spawn(state, spawn_point_id)
    end)
  end

  defp execute_action("destroy_monster", args, _script_name, state),
    do: destroy_mobs(int_list_arg(args, :spawn_ids), state)

  defp execute_action("create_widget", args, _script_name, state) do
    # widgets are recreated fresh, dropping any remembered conditions
    put_in(state, [:widgets, widget_key(args[:type])], %{conditions: %{}})
  end

  defp execute_action("widget_action", args, _script_name, state) do
    if to_string(args[:func]) == "clear" do
      put_in(state, [:widgets, widget_key(args[:type]), :conditions], %{})
    else
      state
    end
  end

  defp execute_action("play_scene_movie", args, _script_name, state) do
    movie_id = int_arg(args, :movie_id)
    widget = get_in(state, [:widgets, :scene_movie]) || %{conditions: %{}, movie_id: nil}
    state = put_in(state, [:widgets, :scene_movie], Map.put(widget, :movie_id, movie_id))

    Context.Field.broadcast(
      state.topic,
      Packets.Trigger.start_movie(to_string(args[:file_name]), movie_id)
    )

    state
  end

  defp execute_action("set_effect", args, _script_name, state) do
    visible = bool_arg(args, :visible)

    Enum.reduce(int_list_arg(args, :trigger_ids), state, fn effect_id, state ->
      Context.Field.broadcast(
        state.topic,
        Packets.Trigger.update_effect(visible, %{id: effect_id})
      )

      state
    end)
  end

  defp execute_action("select_camera_path", args, _script_name, state) do
    Context.Field.broadcast(
      state.topic,
      Packets.Trigger.camera_start(int_list_arg(args, :path_ids), bool_arg(args, :return_view))
    )

    state
  end

  defp execute_action("reset_camera", args, _script_name, state) do
    Context.Field.broadcast(
      state.topic,
      Packets.CameraInterpolation.interpolate(float_arg(args, :interpolation_time))
    )

    state
  end

  defp execute_action("set_onetime_effect", args, _script_name, state) do
    Context.Field.broadcast(
      state.topic,
      Packets.OneTimeEffect.apply(
        int_arg(args, :id),
        bool_arg(args, :enable),
        to_string(args[:path] || "")
      )
    )

    state
  end

  defp execute_action("add_cinematic_talk", args, _script_name, state) do
    Context.Field.broadcast(
      state.topic,
      Packets.Cinematic.talk(
        int_arg(args, :npc_id),
        to_string(args[:illust_id] || ""),
        to_string(args[:msg] || ""),
        int_arg(args, :duration),
        align_key(args[:align])
      )
    )

    state
  end

  # the objective pointer: the client marks the entity's position with the
  # quest text so the player knows where to go next. While the player is
  # being path-moved (scripted sprint/carry) they cannot act on it, so the
  # hint is held until the move completes
  defp execute_action("show_guide_summary", args, _script_name, state) do
    guide = %{
      entity_id: int_arg(args, :entity_id),
      text_id: int_arg(args, :text_id),
      duration: int_arg(args, :duration)
    }

    if guide_held?(state) do
      Map.put(state, :pending_guide, guide)
    else
      Context.Field.broadcast(
        state.topic,
        Packets.Trigger.show_summary(guide.entity_id, guide.text_id, guide.duration)
      )

      state
    end
  end

  defp execute_action("hide_guide_summary", args, _script_name, state) do
    state = Map.put(state, :pending_guide, nil)
    Context.Field.broadcast(state.topic, Packets.Trigger.hide_summary(int_arg(args, :entity_id)))
    state
  end

  # script buffs (carry poses, scene states) applied to players in boxes;
  # tracked so remove_buff can clear them later
  defp execute_action("add_buff", args, _script_name, state) do
    buff_id = int_arg(args, :skill_id)
    level = int_arg(args, :level)
    box_ids = int_list_arg(args, :box_ids)

    players_in_boxes(state, box_ids)
    |> Enum.reduce(state, fn character_id, state ->
      apply_script_buff(state, character_id, buff_id, level)
    end)
  end

  defp execute_action("remove_buff", args, _script_name, state) do
    buff_id = int_arg(args, :skill_id)
    box_ids = int_list_arg(args, :box_id)

    players_in_boxes(state, box_ids)
    |> Enum.reduce(state, fn character_id, state ->
      drop_script_buff(state, character_id, buff_id)
    end)
  end

  # scripted carry: an invisible dummy npc walks the patrol path and each
  # player's client walks the player behind it
  defp execute_action("move_user_path", args, _script_name, state) do
    path_name = to_string(args[:patrol_name])
    patrol = Map.get(state[:patrols] || %{}, path_name)

    case patrol do
      %{way_points: way_points} when way_points != [] ->
        Enum.reduce(
          Map.keys(state.players),
          Map.put(state, :path_move_active, true),
          fn character_id, state ->
            spawn_player_dummy(state, character_id, way_points)
          end
        )

      _ ->
        state
    end
  end

  # teleports the players: soft position move within the map, field change
  # across maps (the field empties and stops after a cross-map move)
  defp execute_action("move_user", args, _script_name, state) do
    map_id = int_arg(args, :map_id)
    portal_id = int_arg(args, :portal_id)

    case Storage.Maps.get_portal(map_id, portal_id) do
      %{} = portal ->
        Enum.reduce(Map.keys(state.players), state, fn character_id, state ->
          {:ok, character} = Managers.Character.call(character_id, :lookup)
          move_player(state, character, map_id, portal)
        end)
        |> then(fn state ->
          send(self(), :maybe_stop)
          state
        end)

      _ ->
        state
    end
  end

  # the tutorial flow is server-driven already; nothing to start
  defp execute_action("start_tutorial", _args, _script_name, state), do: state

  defp execute_action("set_cinematic_ui", args, _script_name, state),
    do: cinematic_ui(int_arg(args, :type), args, state)

  # arms the cutscene skip: while set, a skip request jumps the script to
  # the armed state (an empty string disarms)
  defp execute_action("set_skip", args, script_name, state) do
    skips = Map.put(Map.get(state, :trigger_skips, %{}), script_name, to_string(args[:state]))
    state = Map.put(state, :trigger_skips, skips)
    broadcast(state, Packets.Cinematic.set_skip_state(""))
  end

  # scene skips also tell the client which label to show on the skip button
  defp execute_action("set_scene_skip", args, script_name, state) do
    skips = Map.put(Map.get(state, :trigger_skips, %{}), script_name, to_string(args[:state]))
    state = Map.put(state, :trigger_skips, skips)
    broadcast(state, Packets.Cinematic.set_skip_scene(to_string(args[:action] || "")))
  end

  # scripted dialogue: a speech balloon over the speaking actor's head, or a
  # cinematic-styled talk anchored to the npc. type = 1 means a balloon over
  # the npc; spawn_id 0 means the player speaks; time is display seconds
  defp execute_action("set_dialogue", args, _script_name, state) do
    type = int_arg(args, :type)
    spawn_id = int_arg(args, :spawn_id)
    script = to_string(args[:script] || "")
    duration = int_arg(args, :time) * 1000

    cond do
      spawn_id == 0 ->
        balloon_first_player(state, script, duration, 0)

      type == 1 ->
        case npc_object_id(state, spawn_id) do
          nil ->
            state

          object_id ->
            Context.Field.broadcast(
              state.topic,
              Packets.Cinematic.balloon_talk(object_id, script, duration, 0)
            )

            state
        end

      true ->
        Context.Field.broadcast(
          state.topic,
          Packets.Cinematic.talk(
            spawn_id,
            Integer.to_string(spawn_id),
            script,
            duration,
            align_key(args[:align])
          )
        )

        state
    end
  end

  # a balloon speech queued by the script (add_balloon_talk): the balloon
  # appears over the player (spawn point 0) or the spawn-point npc after
  # delay_tick milliseconds; the duration is already milliseconds
  defp execute_action("add_balloon_talk", args, _script_name, state) do
    script = to_string(args[:msg] || "")
    duration = int_arg(args, :duration)
    delay = int_arg(args, :delay_tick)
    spawn_id = int_arg(args, :spawn_id)

    if spawn_id == 0 do
      balloon_first_player(state, script, duration, delay)
    else
      case npc_object_id(state, spawn_id) do
        nil ->
          state

        object_id ->
          Context.Field.broadcast(
            state.topic,
            Packets.Cinematic.balloon_talk(object_id, script, duration, delay)
          )

          state
      end
    end
  end

  # system sounds inside trigger boxes (or field-wide when no box is
  # configured)
  defp execute_action("play_system_sound_in_box", args, _script_name, state) do
    sound = to_string(args[:sound] || "")
    box_ids = int_list_arg(args, :box_ids)

    if box_ids == [] do
      Context.Field.broadcast(state.topic, Packets.PlaySystemSound.system(sound))
    else
      play_sound_for_players_in_boxes(state, box_ids, sound)
    end

    state
  end

  # loops an emote sequence on a story npc (the collapsed robe, lying
  # recruits): the sequence name resolves to a numeric animation id through
  # the model's animation table and streams in the control packet
  defp execute_action("set_npc_emotion_loop", args, _script_name, state) do
    play_npc_emotion(args, state)
  end

  # a one-shot emote sequence on a story npc — same streaming mechanism as
  # the loop variant; the client plays the sequence's own repetition rules
  defp execute_action("set_npc_emotion_sequence", args, _script_name, state) do
    play_npc_emotion(args, state)
  end

  # walks a story npc along a named patrol path (script move_npc)
  defp execute_action("move_npc", args, _script_name, state) do
    Field.Npc.move_npc(state, int_arg(args, :spawn_id), to_string(args[:patrol_name] || ""))
  end

  # the player loops an emote sequence for a scripted beat
  defp execute_action("set_pc_emotion_loop", args, _script_name, state) do
    sequence = to_string(args[:sequence_name] || "")
    duration = int_arg(args, :duration)
    loop = bool_arg(args, :loop)

    Context.Field.broadcast(state.topic, Packets.Trigger.emotion_loop(sequence, duration, loop))
    state
  end

  # the player plays one or more emote sequences back to back (comma list)
  defp execute_action("set_pc_emotion_sequence", args, _script_name, state) do
    sequence_names =
      args
      |> Map.get(:sequence_names, "")
      |> to_string()
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

    Context.Field.broadcast(state.topic, Packets.Trigger.emotion_sequence(sequence_names))
    state
  end

  # a screen-space caption banner ending a scripted beat (the named-title
  # card)
  defp execute_action("show_caption", args, _script_name, state) do
    Context.Field.broadcast(
      state.topic,
      Packets.Cinematic.caption(
        to_string(args[:type] || ""),
        to_string(args[:title] || ""),
        to_string(args[:desc] || ""),
        to_string(args[:align] || "center"),
        int_arg(args, :duration),
        float_arg(args, :offset_rate_x),
        float_arg(args, :offset_rate_y),
        float_arg(args, :scale)
      )
    )

    state
  end

  # the scripted achievement gate: a trigger condition event for players
  # standing in the box, feeding both the quest and achievement condition
  # pipelines. The knight main quest's "trigger: jordy" beat completes here
  defp execute_action("set_achievement", args, _script_name, state) do
    box_ids = int_list_arg(args, :trigger_id)

    case event_condition_type(args[:type]) do
      nil ->
        # an unknown type matches no condition, same as the reference's
        # ConditionType.unknown
        state

      type ->
        code = to_string(args[:achieve] || "")

        players_in_boxes(state, box_ids)
        |> Enum.each(fn character_id ->
          Managers.Achievement.update(character_id, type, 1, "", 0, code, 0)
          Managers.Quest.update_conditions(character_id, type, 1, "", 0, code, 0)
        end)

        state
    end
  end

  # toggles a trigger sound object (map ambience/chime anchored to the
  # scene); the client resolves the sound data from the map by id
  defp execute_action("set_sound", args, _script_name, state) do
    sound_id = int_arg(args, :trigger_id)
    enabled = bool_arg(args, :enable)
    sounds = Map.get(state, :trigger_sounds, %{})

    case Map.get(sounds, sound_id) do
      %{} = sound ->
        Context.Field.broadcast(state.topic, Packets.Trigger.update_sound(sound_id, enabled))
        put_in(state, [:trigger_sounds, sound_id], Map.put(sound, :visible, enabled))

      _ ->
        state
    end
  end

  # a facial expression overlay on the player (spawn point 0) or the
  # spawn-point npcs
  defp execute_action("face_emotion", args, _script_name, state) do
    emotion = to_string(args[:emotion_name] || "")
    spawn_id = int_arg(args, :spawn_id)

    if spawn_id == 0 do
      case Map.values(state.players) do
        [object_id | _] ->
          Context.Field.broadcast(state.topic, Packets.Trigger.face_emotion(object_id, emotion))

        [] ->
          :ok
      end
    else
      state.npcs
      |> Enum.filter(fn {_object_id, npc} -> npc.spawn_point_id == spawn_id end)
      |> Enum.each(fn {object_id, _npc} ->
        Context.Field.broadcast(state.topic, Packets.Trigger.face_emotion(object_id, emotion))
      end)
    end

    state
  end

  # hides or reveals the player character during scripted camera beats
  # (the hide_player field property)
  defp execute_action("visible_my_pc", args, _script_name, state) do
    visible = bool_arg(args, :is_visible)

    if visible do
      Context.Field.broadcast(state.topic, Packets.FieldProperty.remove(:hide_player))
    else
      Context.Field.broadcast(state.topic, Packets.FieldProperty.add(:hide_player))
    end

    Map.put(state, :hide_player, not visible)
  end

  # TODO: cinematic transitions beyond the letterbox/fade/wipes and opening
  # (fade delays); unknown actions warn loudly so script
  # coverage gaps surface in the log
  defp execute_action(name, _args, _script_name, state) do
    Logger.warning("Unhandled trigger action " <> name)
    state
  end

  defp balloon_first_player(state, script, duration, delay) do
    case Map.values(state.players) do
      [object_id | _] ->
        Context.Field.broadcast(
          state.topic,
          Packets.Cinematic.balloon_talk(object_id, script, duration, delay)
        )

      [] ->
        :ok
    end

    state
  end

  defp play_sound_for_players_in_boxes(state, box_ids, sound) do
    players_in_boxes(state, box_ids)
    |> Enum.each(fn character_id ->
      case Managers.Character.call(character_id, :lookup) do
        {:ok, character} ->
          Net.SenderSession.push(character, Packets.PlaySystemSound.system(sound))

        _ ->
          :ok
      end
    end)
  end

  # the event type defaults to "trigger"
  defp event_condition_type(blank) when blank in [nil, ""], do: :trigger

  defp event_condition_type(name) do
    String.to_existing_atom(Macro.underscore(to_string(name)))
  rescue
    _ -> nil
  end

  defp play_npc_emotion(args, state) do
    spawn_id = int_arg(args, :spawn_id)
    sequence = to_string(args[:sequence_name] || "")

    state.npcs
    |> Enum.filter(fn {_object_id, npc} -> npc.spawn_point_id == spawn_id end)
    |> Enum.reduce(state, fn {object_id, npc}, state ->
      # Types.Npc is a struct: field access must use dot syntax
      model = npc.npc.metadata.model.name

      case Storage.Animations.sequence_id(model, sequence) do
        nil ->
          state

        animation_id ->
          npc = %{npc | animation: animation_id, send_control?: true}
          put_in(state, [:npcs, object_id], npc)
      end
    end)
  end

  defp npc_object_id(state, spawn_point_id) do
    Enum.find_value(state.npcs, fn {object_id, npc} ->
      npc.spawn_point_id == spawn_point_id && object_id
    end)
  end

  defp apply_script_buff(state, character_id, buff_id, level) do
    {:ok, character} = Managers.Character.call(character_id, :lookup)
    {buff_object_id, state} = Field.next_local_id(state)

    buff = %{
      owner: %{object_id: character.object_id},
      object_id: buff_object_id,
      caster: %{object_id: character.object_id},
      start_tick: Ms2ex.sync_ticks(),
      end_tick: Ms2ex.sync_ticks() + 3_600_000,
      skill: %{id: buff_id, level: level},
      stacks: 1,
      enabled: true,
      shield_health: 0
    }

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    sk = Map.get(state, :script_buffs, %{})
    Map.put(state, :script_buffs, Map.put(sk, {character_id, buff_id}, buff))
  end

  defp drop_script_buff(state, character_id, buff_id) do
    sk = Map.get(state, :script_buffs, %{})

    case Map.pop(sk, {character_id, buff_id}) do
      {nil, _sk} ->
        state

      {buff, sk} ->
        Context.Field.broadcast(state.topic, Packets.Buff.send(:remove, buff))
        Map.put(state, :script_buffs, sk)
    end
  end

  defp align_key(nil), do: :center
  defp align_key(key) when is_atom(key), do: key

  defp align_key(other) do
    String.to_existing_atom(Macro.underscore(to_string(other)))
  rescue
    _ -> :center
  end

  # the game data spells the attribute both ways across scripts
  defp players_in_boxes(state, box_ids) do
    boxes = Enum.filter(Map.values(Map.get(state, :trigger_boxes, %{})), &(&1.id in box_ids))

    state.player_positions
    |> Enum.filter(fn {_id, %{position: position}} ->
      is_map(position) and Enum.any?(boxes, &box_contains?(&1, position))
    end)
    |> Enum.map(fn {character_id, _entry} -> character_id end)
  end

  defp spawn_player_dummy(state, character_id, way_points) do
    {:ok, character} = Managers.Character.call(character_id, :lookup)

    case Field.Npc.spawn_follow_dummy(state, character, way_points) do
      {nil, state} ->
        state

      {%FieldNpc{} = dummy, state} ->
        Net.SenderSession.push(character, Packets.FollowNpc.follow(dummy.object_id))
        state
    end
  end

  # portal moves whose target has no walkable ground are refused; scene
  # anchors can sit off the mesh
  defp move_player(state, character, map_id, portal) when map_id == state.map_id do
    if Navigation.valid_position?(state.map_id, portal.position) do
      character = %{character | position: portal.position}
      Managers.Character.call(character, {:update, character})
      Field.Trigger.track_position(state, character.id, portal.position)

      Net.SenderSession.push(
        character,
        Packets.UserMoveByPortal.bytes(character, portal.position, portal.rotation)
      )
    end

    state
  end

  defp move_player(state, character, map_id, portal) do
    state = Field.Character.remove_character(character, state)

    character =
      character
      |> Context.Characters.maybe_discover_map(map_id)
      |> Map.put(:change_map, %{id: map_id, position: portal.position, rotation: portal.rotation})

    Managers.Character.call(character, {:update, character})

    Net.SenderSession.push(
      character,
      Packets.RequestFieldEnter.bytes(map_id, portal.position, portal.rotation)
    )

    state
  end

  defp update_portal(portal_id, args, state) do
    portal = Enum.find(Map.values(state.portals || %{}), &(&1.id == portal_id))

    case portal do
      %{} = portal ->
        portal = %{
          portal
          | visible: bool_arg(args, :visible),
            enable: bool_arg(args, :enable),
            minimap_visible: bool_arg(args, :minimap_visible)
        }

        Context.Field.broadcast(state.topic, Packets.AddPortal.update(portal))

        %{state | portals: Map.put(state.portals, portal.id, portal)}

      _ ->
        state
    end
  end

  defp destroy_mobs(spawn_point_ids, state) do
    state.npc_spawns
    |> Map.values()
    |> Enum.filter(&(&1[:spawn_point_id] in spawn_point_ids))
    |> Enum.flat_map(fn spawn ->
      List.wrap(spawn[:spawned_mobs]) ++ Map.get(spawn, :spawned_npcs, [])
    end)
    |> Enum.reduce(state, fn object_id, state ->
      case Map.fetch(state.npcs, object_id) do
        {:ok, npc} ->
          # reuses the corpse-removal path; a pending removal is a no-op
          send(self(), {:remove_npc, npc})
          state

        :error ->
          state
      end
    end)
  end

  defp cinematic_ui(0, _args, state) do
    # EndCinematic: the UI (and any held guide hint) returns to the player
    Context.Field.broadcast(state.topic, Packets.Cinematic.toggle_ui(false))
    maybe_release_guide_hold(Map.put(state, :cinematic_on, false))
  end

  defp cinematic_ui(1, _args, state) do
    # BeginCinematic: guides held until the cinematic ends
    Context.Field.broadcast(state.topic, Packets.Cinematic.toggle_ui(true))
    Map.put(state, :cinematic_on, true)
  end

  defp cinematic_ui(2, _args, state) do
    Context.Field.broadcast(state.topic, Packets.Cinematic.hide_ui())
    state
  end

  # letterbox bars / fade / wipes frame the cutscene — their black backing
  # is what cinematic dialog bubbles render over; the script text overlays
  # the transition
  defp cinematic_ui(type, args, state) when type in 3..6 do
    script = to_string(args[:script] || "")
    Context.Field.broadcast(state.topic, Packets.Cinematic.view(type, script))
    state
  end

  # black screen with text (scripted intros)
  defp cinematic_ui(9, args, state) do
    script = to_string(args[:script] || "")
    Context.Field.broadcast(state.topic, Packets.Cinematic.opening(script, bool_arg(args, :arg3)))
    state
  end

  defp cinematic_ui(_type, _args, state), do: state

  # -- helpers ---------------------------------------------------------------

  # detection boxes grow by 10 units on every axis to compensate for
  # entity size
  @pad 10.0

  defp box_contains?(box, %{x: x, y: y, z: z}) do
    pos = box.position
    dims = box.dimensions

    x >= pos.x - dims.x / 2 - @pad and x <= pos.x + dims.x / 2 + @pad and
      y >= pos.y - dims.y / 2 - @pad and y <= pos.y + dims.y / 2 + @pad and
      z >= pos.z - dims.z / 2 - @pad and z <= pos.z + dims.z / 2 + @pad
  end

  defp widget_key(name) do
    String.to_existing_atom(Macro.underscore(to_string(name)))
  rescue
    _ -> to_string(name)
  end

  defp int_arg(args, key) when is_atom(key) do
    case Map.get(args, key) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _rest} -> int
          :error -> 0
        end

      value when is_integer(value) ->
        value

      _ ->
        0
    end
  end

  defp float_arg(args, key) when is_atom(key) do
    case Map.get(args, key) do
      value when is_binary(value) ->
        case Float.parse(value) do
          {float, _rest} -> float
          :error -> 0.0
        end

      value when is_number(value) ->
        value * 1.0

      _ ->
        0.0
    end
  end

  defp bool_arg(args, key), do: int_arg(args, key) == 1

  defp int_list_arg(args, key) do
    case Map.get(args, key) do
      value when is_binary(value) -> parse_int_list(value)
      _ -> []
    end
  end

  # int-list args mix single ids and inclusive ranges, e.g. "8003,8005"
  # or the tutorial arrow trails "5001-5025"; ranges expand to every id
  defp parse_int_list(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(&parse_int_span/1)
  end

  defp parse_int_span(part) do
    case Integer.parse(part) do
      {first, "-" <> rest} ->
        case Integer.parse(rest) do
          {last, _rest} -> Enum.to_list(first..last//1)
          :error -> [first]
        end

      {int, _rest} ->
        [int]

      :error ->
        []
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  # scripts declare their execution order; the runtime starts at the first
  defp first_state(%{state_names: [first | _rest]}), do: first
  defp first_state(states), do: states |> Map.keys() |> List.first()
end
