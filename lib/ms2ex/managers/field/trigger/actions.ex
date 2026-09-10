defmodule Ms2ex.Managers.Field.Trigger.Actions do
  @moduledoc """
  Trigger-script action catalog: the server-driven beats a script state
  fires — scene/UI, actors, world state, buffs, items and teleports.
  Unimplemented actions warn in the log so coverage gaps surface per map.
  """

  import Ms2ex.Helpers.TriggerArgs

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Navigation
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  def execute_actions(actions, script_name, state) when is_list(actions) do
    Enum.reduce(actions, state, fn action, state ->
      execute_action(action[:name], action[:args] || %{}, script_name, state)
    end)
  end

  def execute_actions(_actions, _script_name, state), do: state

  defp execute_action("set_mesh", args, _script_name, state) do
    visible = bool_arg(args, :visible)
    meshes = Map.get(state, :trigger_meshes, %{})

    Enum.reduce(int_list_arg(args, :trigger_ids), state, fn mesh_id, state ->
      case Map.get(meshes, mesh_id) do
        %{} = mesh ->
          Managers.Field.broadcast(state.topic, Packets.Trigger.update_mesh(visible, mesh))
          state

        _ ->
          state
      end
    end)
  end

  defp execute_action("set_portal", args, _script_name, state),
    do: update_portal(int_arg(args, :portal_id), args, state)

  defp execute_action("guide_event", args, _script_name, state) do
    Managers.Field.broadcast(state.topic, Packets.Trigger.guide_event(int_arg(args, :event_id)))
    state
  end

  defp execute_action("spawn_monster", args, _script_name, state) do
    Enum.reduce(int_list_arg(args, :spawn_ids), state, fn spawn_point_id, state ->
      Managers.Field.Npc.trigger_spawn(state, spawn_point_id)
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

    Managers.Field.broadcast(
      state.topic,
      Packets.Trigger.start_movie(to_string(args[:file_name]), movie_id)
    )

    state
  end

  defp execute_action("set_effect", args, _script_name, state) do
    visible = bool_arg(args, :visible)

    Enum.reduce(int_list_arg(args, :trigger_ids), state, fn effect_id, state ->
      Managers.Field.broadcast(
        state.topic,
        Packets.Trigger.update_effect(visible, %{id: effect_id})
      )

      state
    end)
  end

  defp execute_action("select_camera_path", args, _script_name, state) do
    Managers.Field.broadcast(
      state.topic,
      Packets.Trigger.camera_start(int_list_arg(args, :path_ids), bool_arg(args, :return_view))
    )

    state
  end

  defp execute_action("reset_camera", args, _script_name, state) do
    Managers.Field.broadcast(
      state.topic,
      Packets.CameraInterpolation.interpolate(float_arg(args, :interpolation_time))
    )

    state
  end

  # slows/speeds up the field's tick rate for a cinematic beat (e.g. a
  # bullet-time dodge sequence); enable false reverts to normal speed
  defp execute_action("set_time_scale", args, _script_name, state) do
    Managers.Field.broadcast(
      state.topic,
      Packets.TimeScale.set(
        bool_arg(args, :enable),
        float_arg(args, :start_scale),
        float_arg(args, :end_scale),
        float_arg(args, :duration),
        int_arg(args, :interpolator)
      )
    )

    state
  end

  # event/minigame UI overlays. rounds = [current, max, min]; a round UI
  # whose min equals its max would display nothing, so it is skipped
  defp execute_action("set_event_ui_round", args, _script_name, state) do
    rounds = int_list_arg(args, :rounds)
    round = Enum.at(rounds, 0) || 1
    max_round = Enum.at(rounds, 1) || 1
    min_round = Enum.at(rounds, 2) || 1

    if min_round != max_round do
      Managers.Field.broadcast(
        state.topic,
        Packets.MassiveEvent.round(round, max_round, min_round, int_arg(args, :v_offset))
      )
    end

    state
  end

  # banner text, optionally scoped to trigger boxes (ids prefixed with "!"
  # select players outside the box; box id 0 means everyone on the field)
  defp execute_action("set_event_ui_script", args, _script_name, state) do
    packet =
      Packets.MassiveEvent.banner(
        banner_type(args[:type]),
        to_string(args[:script] || ""),
        int_arg(args, :duration)
      )

    deliver_to_boxes(state, string_list_arg(args, :box_ids), packet)
  end

  defp execute_action("set_event_ui_countdown", args, _script_name, state) do
    countdown = int_list_arg(args, :round_countdown)

    if length(countdown) == 2 do
      [round, seconds] = countdown

      packet = Packets.MassiveEvent.countdown(to_string(args[:script] || ""), round, seconds)
      deliver_to_boxes(state, string_list_arg(args, :box_ids), packet)
    end

    state
  end

  # tints the field's ambient light (e.g. red alert scenes): the color is
  # "r, g, b" floats, rounded to bytes like the client's Byte3
  defp execute_action("set_ambient_light", args, _script_name, state) do
    case rgb_arg(args[:primary]) do
      {r, g, b} ->
        Managers.Field.broadcast(
          state.topic,
          Packets.FieldProperty.add({:ambient_light, r, g, b})
        )

      nil ->
        :ok
    end

    state
  end

  defp execute_action("set_onetime_effect", args, _script_name, state) do
    Managers.Field.broadcast(
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
    Managers.Field.broadcast(
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

    if Managers.Field.Trigger.guide_held?(state) do
      Map.put(state, :pending_guide, guide)
    else
      Managers.Field.broadcast(
        state.topic,
        Packets.Trigger.show_summary(guide.entity_id, guide.text_id, guide.duration)
      )

      state
    end
  end

  defp execute_action("hide_guide_summary", args, _script_name, state) do
    state = Map.put(state, :pending_guide, nil)
    Managers.Field.broadcast(state.topic, Packets.Trigger.hide_summary(int_arg(args, :entity_id)))
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

    case arrival(map_id, portal_id, state.map_id) do
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
    Managers.Field.broadcast(state.topic, Packets.Cinematic.set_skip_state(""))
    state
  end

  # scene skips also tell the client which label to show on the skip button
  defp execute_action("set_scene_skip", args, script_name, state) do
    skips = Map.put(Map.get(state, :trigger_skips, %{}), script_name, to_string(args[:state]))
    state = Map.put(state, :trigger_skips, skips)

    Managers.Field.broadcast(
      state.topic,
      Packets.Cinematic.set_skip_scene(to_string(args[:action] || ""))
    )

    state
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
            Managers.Field.broadcast(
              state.topic,
              Packets.Cinematic.balloon_talk(object_id, script, duration, 0)
            )

            state
        end

      true ->
        Managers.Field.broadcast(
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
          Managers.Field.broadcast(
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
      Managers.Field.broadcast(state.topic, Packets.PlaySystemSound.system(sound))
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
    Managers.Field.Npc.Patrol.move_npc(
      state,
      int_arg(args, :spawn_id),
      to_string(args[:patrol_name] || "")
    )
  end

  # the player loops an emote sequence for a scripted beat
  defp execute_action("set_pc_emotion_loop", args, _script_name, state) do
    sequence = to_string(args[:sequence_name] || "")
    duration = int_arg(args, :duration)
    loop = bool_arg(args, :loop)

    Managers.Field.broadcast(state.topic, Packets.Trigger.emotion_loop(sequence, duration, loop))
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

    Managers.Field.broadcast(state.topic, Packets.Trigger.emotion_sequence(sequence_names))
    state
  end

  # a screen-space caption banner ending a scripted beat (the named-title
  # card)
  defp execute_action("show_caption", args, _script_name, state) do
    Managers.Field.broadcast(
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
        # an unknown type matches no condition
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
        Managers.Field.broadcast(state.topic, Packets.Trigger.update_sound(sound_id, enabled))
        put_in(state, [:trigger_sounds, sound_id], Map.put(sound, :visible, enabled))

      _ ->
        state
    end
  end

  # enables/disables trigger skill zones — field-owned skill objects (magic
  # practice circles, dungeon hazards) the client renders at the trigger's
  # position until disabled again
  # TODO: server-side zone ticks — field skills with attack effects should
  # damage entities in range (count fires, 150ms apart) instead of only
  # rendering client-side
  defp execute_action("set_skill", args, _script_name, state) do
    trigger_ids = int_list_arg(args, :trigger_ids)
    enabled = bool_arg(args, :enable)

    Enum.reduce(trigger_ids, state, fn trigger_id, state ->
      if enabled do
        enable_trigger_skill(state, trigger_id)
      else
        disable_trigger_skill(state, trigger_id)
      end
    end)
  end

  # script variables: key/value pairs the state machine writes here and
  # reads back through user_value conditions
  defp execute_action("set_user_value", args, _script_name, state) do
    key = to_string(args[:key] || "")
    user_values = Map.put(Map.get(state, :user_values, %{}), key, int_arg(args, :value))
    Map.put(state, :user_values, user_values)
  end

  # flips breakable objects between shown and hidden; the client treats the
  # shown ones as active map features (lane pads, blocking props)
  defp execute_action("set_breakable", args, _script_name, state) do
    enabled = bool_arg(args, :enable)

    set_breakables(state, int_list_arg(args, :trigger_ids), fn b ->
      %{b | state: (enabled && 2) || 4}
    end)
  end

  defp execute_action("set_visible_breakable_object", args, _script_name, state) do
    visible = bool_arg(args, :visible)
    set_breakables(state, int_list_arg(args, :trigger_ids), fn b -> %{b | visible: visible} end)
  end

  # flips interact objects between normal/reactable/hidden
  defp execute_action("set_interact_object", args, _script_name, state) do
    ids = int_list_arg(args, :trigger_ids)

    state_atom =
      case int_arg(args, :state) do
        1 -> :reactable
        2 -> :hidden
        _ -> :normal
      end

    state.interactable
    |> Enum.filter(fn {_uuid, object} -> object.id in ids end)
    |> Enum.each(fn {_uuid, object} ->
      Managers.Field.broadcast(
        state.topic,
        Packets.InteractObject.update(%{object | state: state_atom})
      )
    end)

    state
  end

  # a facial expression overlay on the player (spawn point 0) or the
  # spawn-point npcs
  defp execute_action("face_emotion", args, _script_name, state) do
    emotion = to_string(args[:emotion_name] || "")
    spawn_id = int_arg(args, :spawn_id)

    if spawn_id == 0 do
      case Map.values(state.players) do
        [object_id | _] ->
          Managers.Field.broadcast(state.topic, Packets.Trigger.face_emotion(object_id, emotion))

        [] ->
          :ok
      end
    else
      state.npcs
      |> Enum.filter(fn {_object_id, npc} -> npc.spawn_point_id == spawn_id end)
      |> Enum.each(fn {object_id, _npc} ->
        Managers.Field.broadcast(state.topic, Packets.Trigger.face_emotion(object_id, emotion))
      end)
    end

    state
  end

  # hides or reveals the player character during scripted camera beats
  # (the hide_player field property)
  defp execute_action("visible_my_pc", args, _script_name, state) do
    visible = bool_arg(args, :is_visible)

    if visible do
      Managers.Field.broadcast(state.topic, Packets.FieldProperty.remove(:hide_player))
    else
      Managers.Field.broadcast(state.topic, Packets.FieldProperty.add(:hide_player))
    end

    Map.put(state, :hide_player, not visible)
  end

  # spawns a fixed-position, unowned field item at a map's item spawn
  # point(s) — the ground pickups for scripted quest beats. item_id is used
  # directly when given; otherwise the spawn point's individual/global drop
  # box rolls whatever it is configured with
  defp execute_action("create_item", args, _script_name, state) do
    spawn_ids = int_list_arg(args, :spawn_ids)
    item_id = int_arg(args, :item_id)

    Enum.reduce(spawn_ids, state, &create_spawned_item(&2, &1, item_id))
  end

  # TODO: cinematic transitions beyond the letterbox/fade/wipes and opening
  # (fade delays); unknown actions warn loudly so script coverage gaps
  # surface in the log
  defp execute_action(name, _args, _script_name, state) do
    Logger.warning("Unhandled trigger action " <> name)
    state
  end

  # the script action's type is the set_event_ui kind selector (1 = plain
  # script banner, 3/4/5/6/7 = outcome banners); it maps onto the client's
  # banner table rather than passing through as the banner id itself
  defp banner_type("1"), do: 6

  defp banner_type("3"), do: 2

  defp banner_type("4"), do: 0

  defp banner_type("5"), do: 1

  defp banner_type("6"), do: 3

  defp banner_type("7"), do: 5

  defp banner_type(_), do: 6

  defp set_breakables(state, [], _fun), do: state

  defp set_breakables(state, ids, fun) do
    {entries, state} =
      Enum.reduce(ids, {[], state}, fn id, {entries, state} ->
        case Map.get(state.breakables, id) do
          %{} = breakable ->
            breakable = fun.(breakable)
            entry = %{uuid: breakable.uuid, state: breakable.state, visible: breakable.visible}

            {[%{entry | uuid: breakable.uuid} | entries],
             put_in(state, [:breakables, id], breakable)}

          nil ->
            {entries, state}
        end
      end)

    if entries != [] do
      Managers.Field.broadcast(state.topic, Packets.Breakable.update(Enum.reverse(entries)))
    end

    state
  end

  defp balloon_first_player(state, script, duration, delay) do
    case Map.values(state.players) do
      [object_id | _] ->
        Managers.Field.broadcast(
          state.topic,
          Packets.Cinematic.balloon_talk(object_id, script, duration, delay)
        )

      [] ->
        :ok
    end

    state
  end

  # item_id is used directly when given; the spawn point's own drop boxes
  # (individual needs a character for level/gender/job gating — any online
  # player works since these boxes are shared, unowned field pickups, not
  # per-player rolls) roll on top of it
  defp roll_item_spawn(spawn, item_id, state) do
    direct = if item_id > 0, do: List.wrap(Context.Items.drop_item(item_id, 0, 1)), else: []

    individual =
      case {spawn[:individual_drop_box_id], drop_roll_character(state)} do
        {id, %Schema.Character{} = character} when is_integer(id) and id > 0 ->
          Context.Drops.individual_items(id, character, state.map_id)

        _ ->
          []
      end

    global =
      case spawn[:global_drop_box_id] do
        id when is_integer(id) and id > 0 ->
          Context.Drops.global_items(id, spawn[:global_drop_level] || 1, state.map_id)

        _ ->
          []
      end

    direct ++ individual ++ global
  end

  defp drop_roll_character(state) do
    case Map.keys(state.players) do
      [character_id | _] ->
        case Managers.Character.call(character_id, :lookup) do
          {:ok, character} -> character
          _ -> nil
        end

      [] ->
        nil
    end
  end

  defp enable_trigger_skill(state, trigger_id) do
    case Map.get(state.trigger_skills, trigger_id) do
      %{} = trigger_skill ->
        source_id = Ms2ex.generate_int()
        position = struct(Types.Coord, trigger_skill.position)

        cast =
          Types.SkillCast.build(0, %{
            id: 0,
            skill_id: trigger_skill.skill_id,
            skill_level: trigger_skill.skill_level,
            position: position,
            rotation: struct(Types.Coord, trigger_skill.rotation),
            # first skill tick lands shortly after the zone is placed
            next_tick: Ms2ex.sync_ticks() + 150
          })

        Managers.Field.broadcast(
          state.topic,
          Packets.RegionSkill.add(source_id, cast, [position])
        )

        put_in(state, [:trigger_skills, trigger_id, :source_id], source_id)

      _ ->
        state
    end
  end

  defp disable_trigger_skill(state, trigger_id) do
    case Map.get(state.trigger_skills, trigger_id) do
      %{source_id: source_id} when is_integer(source_id) ->
        Managers.Field.broadcast(state.topic, Packets.RegionSkill.remove(source_id))
        {_, state} = pop_in(state, [:trigger_skills, trigger_id, :source_id])
        state

      _ ->
        state
    end
  end

  defp create_spawned_item(state, spawn_id, item_id) do
    case Map.get(state.item_spawns, spawn_id) do
      nil ->
        state

      spawn ->
        position = struct(Types.Coord, spawn.position)

        spawn
        |> roll_item_spawn(item_id, state)
        |> Enum.reduce(state, &Managers.Field.Item.create_item(position, &1, &2))
    end
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
    {buff_object_id, state} = Managers.Field.next_local_id(state)

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

    Managers.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    sk = Map.get(state, :script_buffs, %{})
    Map.put(state, :script_buffs, Map.put(sk, {character_id, buff_id}, buff))
  end

  defp drop_script_buff(state, character_id, buff_id) do
    sk = Map.get(state, :script_buffs, %{})

    case Map.pop(sk, {character_id, buff_id}) do
      {nil, _sk} ->
        state

      {buff, sk} ->
        Managers.Field.broadcast(state.topic, Packets.Buff.send(:remove, buff))
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

  # a missing box argument defaults to 0, and box 0 is every player on the
  # field
  defp players_in_boxes(state, []), do: Map.keys(state.player_positions)

  defp players_in_boxes(state, box_ids) do
    if 0 in box_ids do
      Map.keys(state.player_positions)
    else
      boxes = Enum.filter(Map.values(Map.get(state, :trigger_boxes, %{})), &(&1.id in box_ids))

      state.player_positions
      |> Enum.filter(fn {_id, %{position: position}} ->
        is_map(position) and Enum.any?(boxes, &Managers.Field.Trigger.box_contains?(&1, position))
      end)
      |> Enum.map(fn {character_id, _entry} -> character_id end)
    end
  end

  # box ids are strings, optionally negated with a leading "!"; id 0 means
  # everyone on the field. Recipients are deduplicated across boxes
  defp deliver_to_boxes(state, box_ids, packet) do
    all_player_ids = Map.keys(state.player_positions)

    recipients =
      Enum.flat_map(box_ids, fn box_id ->
        {negate?, id} = parse_box_id(box_id)

        cond do
          id == 0 and not negate? ->
            all_player_ids

          negate? ->
            Enum.reject(all_player_ids, &(&1 in players_in_boxes(state, [id])))

          true ->
            players_in_boxes(state, [id])
        end
      end)
      |> Enum.uniq()

    Enum.each(recipients, fn character_id ->
      case Managers.Character.call(character_id, :lookup) do
        {:ok, character} -> Net.SenderSession.push(character, packet)
        _ -> :ok
      end
    end)

    state
  end

  defp parse_box_id(box_id) do
    box_id = String.trim(box_id)

    if String.starts_with?(box_id, "!") do
      {true, box_id |> String.trim_leading("!") |> Integer.parse() |> elem(0)}
    else
      {false, Integer.parse(box_id) |> elem(0)}
    end
  end

  defp spawn_player_dummy(state, character_id, way_points) do
    {:ok, character} = Managers.Character.call(character_id, :lookup)

    case Managers.Field.Npc.spawn_follow_dummy(state, character, way_points) do
      {nil, state} ->
        state

      {%Types.FieldNpc{} = dummy, state} ->
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
      Managers.Field.Trigger.track_position(state, character.id, portal.position)

      Net.SenderSession.push(
        character,
        Packets.UserMoveByPortal.bytes(character, portal.position, portal.rotation)
      )
    end

    state
  end

  defp move_player(state, character, map_id, portal) do
    state = Managers.Field.Character.remove_character(character, state)

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

  # same-map moves use the named portal (a missing one is a no-op).
  # Cross-map moves pass the portal id as a hint only — the destination may
  # not have it (e.g. the Door of Light transition map ships no portals at
  # all), so fall back to its return portal, then its default spawn
  defp arrival(map_id, portal_id, current_map_id) when map_id == current_map_id do
    Storage.Maps.get_portal(map_id, portal_id)
  end

  defp arrival(map_id, portal_id, current_map_id) do
    Storage.Maps.get_portal(map_id, portal_id) ||
      Enum.find(Storage.Maps.get_portals(map_id), &(&1.target_map_id == current_map_id)) ||
      Storage.Maps.get_field_spawn(map_id)
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

        Managers.Field.broadcast(state.topic, Packets.AddPortal.update(portal))

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
      (List.wrap(spawn[:spawned_mobs]) ++ Map.get(spawn, :spawned_npcs, []))
      |> Enum.map(&{&1, spawn.spawn_point_id})
    end)
    |> Enum.reduce(state, fn {object_id, point_id}, state ->
      case Map.fetch(state.npcs, object_id) do
        {:ok, npc} ->
          # reuses the corpse-removal path; a pending removal is a no-op
          send(self(), {:remove_npc, npc})
          # the destroyed npc frees its slot so a later spawn_monster on the
          # same point can refill it
          untrack_npc(state, point_id, object_id)

        :error ->
          state
      end
    end)
  end

  defp untrack_npc(state, point_id, object_id) do
    spawn = state.npc_spawns[point_id]

    spawn =
      Map.update(spawn, :spawned_npcs, [], &List.delete(&1, object_id))
      |> Map.update(:spawned_mobs, [], &List.delete(&1, object_id))

    put_in(state, [:npc_spawns, point_id], spawn)
  end

  defp cinematic_ui(0, _args, state) do
    # EndCinematic: the UI (and any held guide hint) returns to the player
    Managers.Field.broadcast(state.topic, Packets.Cinematic.toggle_ui(false))
    Managers.Field.Trigger.maybe_release_guide_hold(Map.put(state, :cinematic_on, false))
  end

  defp cinematic_ui(1, _args, state) do
    # BeginCinematic: guides held until the cinematic ends
    Managers.Field.broadcast(state.topic, Packets.Cinematic.toggle_ui(true))
    Map.put(state, :cinematic_on, true)
  end

  defp cinematic_ui(2, _args, state) do
    Managers.Field.broadcast(state.topic, Packets.Cinematic.hide_ui())
    state
  end

  # letterbox bars / fade / wipes frame the cutscene — their black backing
  # is what cinematic dialog bubbles render over; the script text overlays
  # the transition
  defp cinematic_ui(type, args, state) when type in 3..6 do
    script = to_string(args[:script] || "")
    Managers.Field.broadcast(state.topic, Packets.Cinematic.view(type, script))
    state
  end

  # black screen with text (scripted intros)
  defp cinematic_ui(9, args, state) do
    script = to_string(args[:script] || "")

    Managers.Field.broadcast(
      state.topic,
      Packets.Cinematic.opening(script, bool_arg(args, :arg3))
    )

    state
  end

  defp cinematic_ui(_type, _args, state), do: state
end
