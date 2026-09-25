defmodule Ms2ex.Managers.Field.Npc.Battle do
  @moduledoc """
  Mob aggro and chase: target acquisition, target retention and pathed
  movement toward the engaged target.

  Target acquisition scans the field's players for anyone inside the mob's
  sight band (metadata `distance.sight` with the up/down height slack),
  picking the closest. Retention keeps an engaged target while it stays
  inside the (wider) last-sight band, dropping it as soon as the player
  leaves the field or escapes. Being damaged aggros the attacker directly.

  While engaged, the mob paths over the navmesh toward its target and stops
  inside its attack range; the chase streams continuously so the client
  never sees a stand mid-run. When the target escapes (or leaves the
  field), a displaced mob walks back to the point where it spawned —
  healing to full and clearing its attacker tags on arrival — while still
  scanning, so it can re-engage a player on the way home. Out of battle,
  the mob's weighted idle routines roll (`Npc.Idle`): standing, bore
  emotes, or a wander leg toward a random point inside its move area
  (battle mode `:wander`). The game's per-mob XML decision trees drive
  finer combat behavior; this basic AI applies one fixed battle routine
  and the tree runtime is a later step (see docs/features/mob-ai.md).
  """

  alias Ms2ex.Managers.Field.Npc.Idle
  alias Ms2ex.Managers.Field.Npc.Patrol
  alias Ms2ex.Navigation
  alias Ms2ex.Storage
  alias Ms2ex.Types

  # cadence for the proximity scan (ms) used when the mob has no target
  @scan_interval_ms 500
  # minimum spacing between path re-computations while chasing
  @repath_interval_ms 500
  # re-path early when the target has moved this far from the pathed goal
  @repath_target_drift 150
  # a standing engaged mob only resumes the chase once the target is this
  # much beyond stop range, so slow-moving targets don't flip the mob
  # between run and stand every few ticks
  @resume_margin 60
  # a mob counts as home once it is this close to its spawn point
  @home_range 60
  # a wander leg completes once the mob is this close to its goal
  @wander_arrive_range 30
  # a disengaged mob only walks home when it is at least this far from its
  # spawn point; otherwise losing aggro where it stands is enough
  @home_threshold 150
  # how long a mob keeps retrying an unreachable target before it gives up
  # and walks home
  @give_up_ms 4_000
  # a hit-aggroed mob keeps its attacker for at least this long before the
  # last-sight drop applies, so ranged pulls (attacker outside sight) work
  @aggro_hold_ms 5_000
  # skill cast timing: the hit lands mid-swing and the whole cast occupies the
  # mob (state PcSkill + attack animation) for the attack sequence's playback
  # length. When the model carries no animation timing the fixed stand-ins
  # below drive the swing
  @fallback_duration_ms 1_000
  # share of the swing playback after which the hit lands (attack keyframes
  # sit around this mark)
  @hit_point_fraction 0.4
  # a landed hit still requires the target to be within the attack range
  # (plus slack for movement between cast start and hit)
  @cast_range_slack 60
  # fastest a mob re-attacks after a cast finishes
  @min_attack_interval_ms 750
  # movement is integrated over at most this window; a long stall (process
  # hiccup, mob standing at range) never becomes one giant teleport step
  @max_step_ms 200

  @type t :: %{
          mode: :chase | :return | :wander,
          target_id: integer() | nil,
          target_object_id: integer() | nil,
          stop_range: float(),
          path: [Types.Coord.t()] | nil,
          path_index: non_neg_integer(),
          goal: Types.Coord.t() | nil,
          next_repath_at: integer(),
          last_move_at: integer(),
          keep_until: integer(),
          no_route_since: integer() | nil,
          cast: map() | nil,
          # playback end of the swing that just resolved: the mob keeps the
          # swing animation (and stays un-attacking) until it elapses
          swing_until: integer() | nil,
          next_attack_at: integer(),
          attack_counter: non_neg_integer(),
          hit_event: map() | nil
        }

  # -- engagement ----------------------------------------------------------------

  @doc """
  Engages the mob on the character that damaged it. Direct hit-aggro: the
  mob turns on its attacker immediately rather than waiting for the next
  proximity scan to notice them.
  """
  def aggro(%Types.FieldNpc{type: :mob, dead?: false} = npc, character, now) do
    # the attacker's player object id feeds the boss bar target slot; the
    # character id is the identity aggro actually tracks
    battle = new_battle(npc, character.id, Map.get(character, :object_id), now)
    battle = %{battle | keep_until: now + @aggro_hold_ms}
    # engaging cancels the idle routine and any bore emote it was playing:
    # the battle owns the presentation from here
    %{
      npc
      | battle: battle,
        next_target_scan_at: now + @scan_interval_ms,
        idle: nil,
        emote: nil,
        send_control?: true
    }
  end

  def aggro(npc, _character, _now), do: npc

  @doc """
  Per-tick battle update for one mob: scans for a target when idle, then
  validates and chases the target while engaged, or walks home while
  returning. Returns `{npc, hits}` — the updated npc plus any skill hits
  the field must apply. The field state is read-only input.
  """
  def tick(%Types.FieldNpc{type: :mob, dead?: false} = npc, field_state, now) do
    cond do
      npc.battle ->
        case tick_battle(npc, field_state, now) do
          {%Types.FieldNpc{} = result, hits} when is_list(hits) ->
            {result, hits}

          other ->
            raise "tick_battle returned a non {npc, hits-list}: mode=#{npc.battle.mode} val=#{inspect(other, limit: 2)} position=#{inspect(npc.position)}"
        end

      now >= npc.next_target_scan_at ->
        npc = scan(npc, field_state, now)
        npc = %{npc | next_target_scan_at: now + @scan_interval_ms}

        # an idle scan keeps the mob on its idle routines; a fresh engagement
        # starts chasing on the next tick, as before
        case npc.battle do
          nil -> {Idle.tick(npc, now), []}
          _battle -> {npc, []}
        end

      true ->
        {Idle.tick(npc, now), []}
    end
  end

  def tick(npc, _field_state, _now), do: {npc, []}

  defp tick_battle(npc, field_state, now) do
    case npc.battle.mode do
      :chase ->
        npc = validate_target(npc, field_state, now)

        # a disengage from a displaced mob switches to walking home
        case npc.battle do
          %{mode: :chase} = battle -> chase(npc, battle, field_state, now)
          %{mode: :return} = battle -> return_tick(npc, battle, now)
          nil -> {npc, []}
        end

      :return ->
        # a returning mob ignores sight while walking home — otherwise it
        # would oscillate at the leash boundary re-chasing the player it is
        # walking away from. Attacking it re-engages (aggro/2)
        return_tick(npc, npc.battle, now)

      :wander ->
        # an idle wander leg walks its static goal; the arrival hands the mob
        # back to its idle routines (attacking it re-engages through aggro/2)
        if square_distance(npc.position, npc.battle.goal) < square(@wander_arrive_range) do
          {Idle.arrive(npc), []}
        else
          walk(npc, npc.battle, npc.battle.goal, now)
        end
    end
  end

  # -- target acquisition & retention -----------------------------------------------

  # players standing on the field right now: {character_id, object_id,
  # live position}. players without a synced position yet (joined but no
  # user sync) are invisible to the scan, and so are dead players — a
  # tombstone never draws aggro
  defp player_positions(field_state) do
    dead = Map.get(field_state, :tombstones, %{})

    field_state.players
    |> Enum.reject(fn {character_id, _object_id} -> Map.has_key?(dead, character_id) end)
    |> Enum.flat_map(fn {character_id, object_id} ->
      case get_in(field_state, [:player_positions, character_id, :position]) do
        %Types.Coord{} = position -> [{character_id, object_id, position}]
        _ -> []
      end
    end)
  end

  defp scan(npc, field_state, now) do
    bands = sight_bands(npc)

    case closest_player(player_positions(field_state), npc.position, bands) do
      nil ->
        npc

      {character_id, object_id, _position} ->
        battle = new_battle(npc, character_id, object_id, now)
        %{npc | battle: battle, send_control?: true}
    end
  end

  # closest player inside the sight band, or nil
  defp closest_player(players, position, bands) do
    players
    |> Enum.map(fn entry = {_id, _oid, player_pos} ->
      {square_distance(position, player_pos), entry}
    end)
    |> Enum.filter(fn {_d2, {_id, _oid, player_pos}} ->
      in_sight_band?(position, player_pos, bands)
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> nil end)
    |> case do
      nil -> nil
      {_distance, entry} -> entry
    end
  end

  defp in_sight_band?(position, target_position, bands) do
    square_distance(position, target_position) < square(bands.sight) and
      in_height_band?(position, target_position, bands.height_up, bands.height_down)
  end

  # drops the target when it died (a tombstone stands on the field), left
  # the field, or — past the hit-aggro hold window — escaped the
  # last-sight band; a mob dragged beyond its last-sight radius from its
  # spawn point is leashed home as well. A dropped target disengages the
  # mob (walking home when displaced), and the regular scan can pick a
  # new target from there
  defp validate_target(npc, field_state, now) do
    character_id = npc.battle.target_id
    on_field? = Map.has_key?(field_state.players, character_id)
    position = get_in(field_state, [:player_positions, character_id, :position])
    dead? = Map.has_key?(Map.get(field_state, :tombstones, %{}), character_id)

    held? = now < npc.battle.keep_until
    bands = sight_bands(npc)

    leashed? =
      square_distance(npc.position, npc.origin) > square(bands.last_sight)

    keep? =
      not dead? and on_field? and match?(%Types.Coord{}, position) and
        (held? or (not leashed? and in_last_sight_band?(npc.position, position, bands)))

    if keep? do
      npc
    else
      disengage(npc, now)
    end
  end

  defp in_last_sight_band?(position, target_position, bands) do
    square_distance(position, target_position) < square(bands.last_sight) and
      in_height_band?(position, target_position, bands.last_height_up, bands.last_height_down)
  end

  # vertical band with the reference's slack on the lower edge
  defp in_height_band?(position, target_position, up, down) do
    dz = target_position.z - position.z
    dz <= up and dz >= -(down + 10)
  end

  # end of combat: an undisplaced mob simply goes idle; one that chased the
  # player away from its spawn point walks back home first
  defp disengage(npc, now) do
    idle = %{
      npc
      | battle: nil,
        velocity: {0, 0, 0},
        animation: sequence_id(npc, "Idle_A") || npc.animation,
        send_control?: true
    }

    if displaced?(npc) do
      %{idle | battle: return_battle(npc, now)}
    else
      idle
    end
  end

  defp displaced?(npc),
    do: square_distance(npc.position, npc.origin) > square(@home_threshold)

  defp return_battle(npc, now) do
    %{
      mode: :return,
      target_id: nil,
      target_object_id: nil,
      stop_range: 0.0,
      path: nil,
      path_index: 1,
      goal: npc.origin,
      next_repath_at: now,
      last_move_at: now,
      keep_until: 0,
      no_route_since: nil
    }
  end

  # walks home; the goal is static so re-paths only happen on exhaustion or
  # the cadence window
  defp return_tick(npc, battle, now) do
    if square_distance(npc.position, battle.goal) < square(@home_range) do
      {arrive_home(npc), []}
    else
      walk(npc, battle, battle.goal, now)
    end
  end

  # back home: back to idle, fully healed, attacker tags cleared so the
  # next fight tags its own attackers
  defp arrive_home(npc) do
    %{
      npc
      | battle: nil,
        velocity: {0, 0, 0},
        animation: sequence_id(npc, "Idle_A") || npc.animation,
        stats: put_in(npc.stats, [:health, :current], npc.stats.health.total),
        first_attacker: nil,
        last_attacker: nil,
        damage_dealers: %{},
        stat_dirty?: true,
        send_control?: true
    }
  end

  # -- chase ------------------------------------------------------------------------

  defp chase(npc, battle, field_state, now) do
    target_position = get_in(field_state, [:player_positions, battle.target_id, :position])
    d2 = square_distance(npc.position, target_position)

    cond do
      # mid-cast: hold position facing the target until the swing resolves
      battle.cast ->
        cast_tick(npc, battle, field_state, target_position, now)

      d2 < square(battle.stop_range) ->
        attack_or_stand(npc, battle, field_state, target_position, now)

      # standing with the target just beyond range: hold until it clearly
      # pulls away instead of flipping between stand and run every tick
      npc.velocity == {0, 0, 0} and d2 < square(battle.stop_range + @resume_margin) ->
        {stand(npc, battle, target_position, now), []}

      true ->
        walk(npc, battle, target_position, now)
    end
  end

  # inside attack range: swing when the cooldown allows, otherwise hold
  # position facing the target
  defp attack_or_stand(npc, battle, field_state, target_position, now) do
    if now >= battle.next_attack_at and has_skill?(npc) and castable?(npc) do
      npc = start_cast(npc, battle, target_position, now)
      # the swing starts immediately: resolve its hit when due
      cast_tick(npc, npc.battle, field_state, target_position, now)
    else
      {stand(npc, battle, target_position, now), []}
    end
  end

  # a cast whose motion sequences the model's rig cannot play is cancelled
  # before it starts: a mob never attacks with an animation it does not
  # have (the swing would land as invisible damage)
  defp castable?(npc) do
    [entry | _] = get_in(npc.npc.metadata, [:skill])

    case skill_level_doc(entry.id, entry.level) do
      %{} = level_doc ->
        motions = swing_motions(npc, level_doc)
        motions != [] and Enum.all?(motions, & &1)

      _ ->
        false
    end
  end

  # inside attack range: hold position facing the target
  defp stand(npc, battle, target_position, now) do
    was_moving = npc.velocity != {0, 0, 0}
    rotation = face_toward(npc.position, target_position, npc.rotation)
    animation = stand_animation(npc, battle, now)
    anim_changed? = animation != npc.animation

    npc = %{
      npc
      | battle: %{battle | path: nil, path_index: 1, goal: nil, last_move_at: now},
        velocity: {0, 0, 0},
        animation: animation
    }

    if was_moving or rotation != npc.rotation or anim_changed? do
      %{npc | rotation: rotation, send_control?: true}
    else
      npc
    end
  end

  # an active cast owns the presentation until it resolves, and the swing
  # keeps its animation through the resolve until the playback ends; outside
  # a swing the mob settles into its combat idle
  defp stand_animation(npc, battle, now) do
    cond do
      battle.cast -> npc.animation
      swing_tailing?(battle, now) -> npc.animation
      true -> combat_idle_id(npc)
    end
  end

  defp swing_tailing?(battle, now),
    do: is_integer(battle.swing_until) and now < battle.swing_until

  defp combat_idle_id(npc) do
    sequence_id(npc, "Attack_Idle_A") || sequence_id(npc, "Idle_A") || npc.animation
  end

  defp has_skill?(npc), do: get_in(npc.npc.metadata, [:skill]) != []

  # begins a swing: pins the mob in PcSkill with the motion's sequence, the
  # hit lands mid-swing and the cast occupies the mob for the swing's
  # playback length
  defp start_cast(npc, battle, target_position, now) do
    [entry | _] = get_in(npc.npc.metadata, [:skill])
    skill_id = entry.id
    skill_level = entry.level
    level_doc = skill_level_doc(skill_id, skill_level)

    motions = swing_motions(npc, level_doc)
    {attack_motion_index, attack} = swing_attack(level_doc) || {0, nil}

    {hit_offset_ms, duration_ms} =
      cast_timing(npc, level_doc, motions, attack_motion_index, attack)

    rotation = face_toward(npc.position, target_position, npc.rotation)

    cast = %{
      skill_id: skill_id,
      skill_level: skill_level,
      # the cast opens on the first motion's sequence
      sequence_id: motions && Enum.find_value(motions, fn m -> m && m.sequence_id end),
      range: attack_range(attack, npc),
      rate: attack_rate(attack),
      magic_path_id: attack_magic_path_id(attack),
      arrow_overlap?: attack_arrow_overlap?(attack),
      started_at: now,
      # each later motion's sequence takes over when its playback starts
      motion_switches: motion_switches(motions),
      hit_at: now + hit_offset_ms,
      end_at: now + duration_ms,
      hit_done?: false
    }

    npc = %{
      npc
      | battle: %{battle | cast: cast, last_move_at: now},
        velocity: {0, 0, 0},
        rotation: rotation,
        animation: cast.sequence_id || npc.animation,
        send_control?: true
    }

    npc
  end

  # resolves the swing: the hit lands when the windup is over; hold position
  # facing the target through the windup, land the hit if the target is still
  # in reach, then hand the hit to the field for application
  defp cast_tick(npc, battle, field_state, target_position, now) do
    {npc, battle} = advance_cast_motion(npc, battle, now)
    cast = battle.cast

    if now < cast.hit_at do
      # windup: hold position facing the target
      {stand(npc, battle, target_position, now), []}
    else
      target_position = get_in(field_state, [:player_positions, battle.target_id, :position])

      in_range? =
        match?(%Types.Coord{}, target_position) and
          square_distance(npc.position, target_position) <
            square(cast.range + @cast_range_slack)

      npc = %{
        npc
        | velocity: {0, 0, 0},
          rotation: face_toward(npc.position, target_position, npc.rotation),
          send_control?: true
      }

      # the cooldown floor and the swing's playback both gate the next
      # swing: the mob never re-attacks while its attack animation plays
      battle = %{
        battle
        | cast: nil,
          swing_until: cast.end_at,
          next_attack_at: max(now + @min_attack_interval_ms, cast.end_at),
          last_move_at: now
      }

      if in_range? do
        hit = %{
          character_id: battle.target_id,
          caster_object_id: npc.object_id,
          target_object_id: battle.target_object_id,
          skill_id: cast.skill_id,
          skill_level: cast.skill_level,
          # the launch point and reach: the impact re-check runs against
          # them when the projectile lands
          position: npc.position,
          range: cast.range,
          direction: aim_direction(npc.position, target_position),
          attack: get_in(npc.npc.metadata, [:stat, :stats, :physical_atk]) || 0,
          rate: cast.rate,
          magic_path_id: cast.magic_path_id,
          arrow_overlap?: cast.arrow_overlap?,
          travel_ms: projectile_travel_ms(cast.magic_path_id, npc.position, target_position),
          server_tick: now,
          attack_counter: battle.attack_counter + 1
        }

        {%{npc | battle: %{battle | hit_event: hit, attack_counter: battle.attack_counter + 1}},
         [hit]}
      else
        {%{npc | battle: battle}, []}
      end
    end
  end

  # streams the swing's motions: when one motion's playback ends, the next
  # motion's sequence takes over the model (the windup visibly hands over
  # to the firing swing instead of the cast looping its first motion)
  defp advance_cast_motion(npc, battle, now) do
    cast = battle.cast
    elapsed = now - cast.started_at

    {due, rest} =
      Enum.split_while(cast.motion_switches, fn {at, _sequence_id} -> elapsed >= at end)

    case due do
      [] ->
        {npc, battle}

      _ ->
        {_at, sequence_id} = List.last(due)
        battle = %{battle | cast: %{cast | motion_switches: rest}}

        npc =
          if sequence_id && npc.animation != sequence_id do
            %{npc | animation: sequence_id, send_control?: true}
          else
            npc
          end

        {npc, battle}
    end
  end

  # the hit event flows out through Npc.tick: the character manager computes
  # the final damage against its own defenses and the field broadcasts it
  defp aim_direction(%Types.Coord{} = from, %Types.Coord{} = to) do
    dx = to.x - from.x
    dy = to.y - from.y
    dz = to.z - from.z
    dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist == 0 do
      %Types.Coord{x: 0, y: 0, z: 0}
    else
      %Types.Coord{x: dx / dist, y: dy / dist, z: dz / dist}
    end
  end

  # outside attack range: keep a fresh path to the target and advance along it
  defp walk(npc, battle, target_position, now) do
    if stationary?(npc) do
      # rooted mobs (zero movement speed — e.g. the plants of Ludibrium
      # fields) cannot pursue: they stand their ground and only strike
      # when the target comes into reach
      {stand(npc, battle, target_position, now), []}
    else
      walk_chase(npc, battle, target_position, now)
    end
  end

  # a mob with any locomotion speed moves at its fastest gait (Run_A, or
  # Walk_A for walk-only mobs); one with neither is rooted in place
  defp stationary?(npc), do: chase_speed(npc) == 0.0

  defp chase_speed(npc) do
    case Patrol.npc_speed(npc, :run_speed) do
      speed when speed > 0.0 -> speed
      _ -> Patrol.npc_speed(npc, :walk_speed)
    end
  end

  defp walk_chase(npc, battle, target_position, now) do
    stale? =
      battle.path == nil or
        square_distance(battle.goal, target_position) > square(@repath_target_drift) or
        now >= battle.next_repath_at

    battle =
      if stale? do
        repath(npc, battle, target_position, now)
      else
        battle
      end

    case battle.path do
      nil ->
        if give_up?(battle, now) do
          {disengage(npc, now), []}
        else
          # no walkable route right now (e.g. the player is on another
          # navmesh island): hold until the next re-path window
          {%{npc | battle: %{battle | last_move_at: now}, velocity: {0, 0, 0}}, []}
        end

      path ->
        npc = start_running(npc)
        {npc, battle} = advance(npc, battle, path, now)

        # the path was consumed while still outside stop range: extend it in
        # this same tick so the run does not stutter into a stand (a stand
        # tick makes the client restart the walk animation and drop
        # interpolation, which reads as flicker and micro-teleports)
        if battle.path == nil do
          extend_path(npc, battle, target_position, now)
        else
          # mid-path: the run continues on the next tick — the updated battle
          # (last_move_at, path index) must merge back into the npc or the
          # next tick's step budget balloons to the max-step clamp
          {%{npc | battle: battle}, []}
        end
    end
  end

  defp extend_path(npc, battle, target_position, now) do
    battle = repath(npc, battle, target_position, now)

    case battle.path do
      nil ->
        # still no route (throttled): hold until the next re-path window
        {%{npc | battle: battle, velocity: {0, 0, 0}}, []}

      path ->
        npc = start_running(npc)
        {npc, battle} = advance(npc, battle, path, now)
        {%{npc | battle: battle}, []}
    end
  end

  # an unreachable target (player on a ledge / other navmesh island) is
  # chased for a grace period, then dropped
  defp give_up?(%{no_route_since: nil}, _now), do: false

  defp give_up?(%{no_route_since: since}, now), do: now - since >= @give_up_ms

  defp repath(npc, battle, target_position, now) do
    case Navigation.find_path(npc.map_id, npc.position, target_position) do
      {:ok, path} ->
        # index 1: point 0 is the mob's own snapped position
        %{
          battle
          | path: path,
            path_index: 1,
            goal: target_position,
            next_repath_at: now + @repath_interval_ms,
            no_route_since: nil
        }

      :error ->
        # stamp when the target first turned unreachable so the give-up
        # timer can measure a continuous failure stretch
        %{
          battle
          | path: nil,
            next_repath_at: now + @repath_interval_ms,
            no_route_since: battle.no_route_since || now
        }
    end
  end

  # advances along the path for the time elapsed since the last move; several
  # waypoints may be consumed within one tick when they are close together
  defp advance(npc, battle, path, now) do
    dt = (now - battle.last_move_at) |> max(1) |> min(@max_step_ms)
    speed = chase_speed(npc)
    budget = speed * dt / 1000.0

    battle = %{battle | last_move_at: now}
    walk_segments(npc, battle, path, budget, speed)
  end

  defp walk_segments(npc, battle, path, budget, speed) do
    case Enum.at(path, battle.path_index) do
      nil ->
        # path consumed without getting in range (short path): clear it so
        # the next tick re-paths
        {%{npc | velocity: {0, 0, 0}}, %{battle | path: nil}}

      waypoint ->
        step = step_toward(npc.position, waypoint, budget, speed)

        case Navigation.snap_to_floor(npc.map_id, step.position) do
          nil ->
            # no walkable surface for this step: hold position; movement
            # rides the navmesh or it does not happen
            {%{npc | velocity: {0, 0, 0}}, battle}

          snapped ->
            commit_step(npc, battle, path, waypoint, snapped, step, speed)
        end
    end
  end

  defp commit_step(npc, battle, _path, waypoint, snapped, %{kind: :moving} = step, _speed) do
    npc = move_step(npc, snapped, waypoint, step.velocity)
    {npc, battle}
  end

  defp commit_step(npc, battle, path, waypoint, snapped, %{kind: :arrived} = step, speed) do
    battle = %{battle | path_index: battle.path_index + 1}

    # keep the run flowing through the corner: aim the velocity at the
    # next waypoint instead of announcing a stand between segments
    npc =
      move_step(
        npc,
        snapped,
        waypoint,
        carry_velocity(snapped, path, battle.path_index, speed)
      )

    if step.leftover > 0 do
      walk_segments(npc, battle, path, step.leftover, speed)
    else
      {npc, battle}
    end
  end

  defp move_step(npc, position, waypoint, velocity) do
    %{
      npc
      | position: position,
        velocity: velocity,
        rotation: face_toward(position, waypoint, npc.rotation),
        send_control?: true
    }
  end

  # keeps the velocity streaming across corners: aims at the next waypoint
  # when one follows, zero only at the end of the path
  defp carry_velocity(from, path, index, speed) do
    case Enum.at(path, index) do
      nil ->
        {0.0, 0.0, 0.0}

      next ->
        dx = next.x - from.x
        dy = next.y - from.y
        dz = next.z - from.z
        dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist == 0 do
          {0.0, 0.0, 0.0}
        else
          {dx / dist * speed, dy / dist * speed, dz / dist * speed}
        end
    end
  end

  # -- helpers ------------------------------------------------------------------------

  defp new_battle(npc, character_id, object_id, now) do
    %{
      mode: :chase,
      target_id: character_id,
      target_object_id: object_id,
      stop_range: stop_range(npc),
      path: nil,
      path_index: 1,
      goal: nil,
      next_repath_at: now,
      last_move_at: now,
      # scan-acquired targets have no hold window (now); hit-aggro overrides
      # with the engagement hold
      keep_until: now,
      no_route_since: nil,
      cast: nil,
      swing_until: nil,
      next_attack_at: now,
      attack_counter: 0,
      hit_event: nil
    }
  end

  @doc """
  An idle wander leg toward a static goal: the same pathed-walk machinery
  the chase and the trip home ride, minus a target to fight. Arrival hands
  the mob back to `Npc.Idle`.
  """
  def wander_battle(%Types.Coord{} = goal, now) do
    %{
      mode: :wander,
      target_id: nil,
      target_object_id: nil,
      stop_range: 0.0,
      path: nil,
      path_index: 1,
      goal: goal,
      next_repath_at: now,
      last_move_at: now,
      keep_until: 0,
      no_route_since: nil,
      cast: nil,
      swing_until: nil,
      next_attack_at: 0,
      attack_counter: 0,
      hit_event: nil
    }
  end

  defp skill_level_doc(skill_id, skill_level) do
    case Storage.Skills.get_meta(skill_id) do
      %{levels: levels} -> levels[to_string(skill_level)]
      _ -> nil
    end
  end

  # the swing's motion timeline: one entry per skill motion with the
  # sequence resolved against the model's rig and its playback length at
  # the motion's sequence speed. A motion whose sequence the rig cannot
  # play leaves a nil entry and marks the swing uncastable — the game
  # cancels such casts rather than landing damage with no animation
  defp swing_motions(npc, level_doc) do
    model = get_in(npc.npc.metadata, [:model, :name])

    level_doc
    |> get_in([:motions])
    |> List.wrap()
    |> Enum.map(fn motion ->
      name = get_in(motion || %{}, [:motion_property, :sequence_name])

      speed = get_in(motion || %{}, [:motion_property, :sequence_speed]) || 1.0
      speed = if is_number(speed) and speed > 0, do: speed * 1.0, else: 1.0

      case Storage.Animations.sequence_time(model, name) do
        seconds when is_number(seconds) and seconds > 0 ->
          %{sequence_id: sequence_id(npc, name), ms: trunc(seconds * 1000 / speed)}

        _ ->
          nil
      end
    end)
  end

  # the attack the swing lands with: the first projectile-carrying attack
  # (later motions often fire the actual shot while earlier ones are pure
  # windups), falling back to the very first attack of the set. Each attack
  # pairs with its motion index so the hit lands inside that motion's
  # playback
  defp swing_attack(level_doc) do
    attacks =
      level_doc
      |> get_in([:motions])
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.flat_map(fn {motion, index} ->
        motion
        |> Map.get(:attacks, [])
        |> List.wrap()
        |> Enum.map(&{index, &1})
      end)

    Enum.find(attacks, fn {_index, attack} -> attack_magic_path_id(attack) > 0 end) ||
      Enum.at(attacks, 0)
  end

  defp attack_point_name(attack) do
    case get_in(attack || %{}, [:point]) do
      name when is_binary(name) -> name
      _ -> nil
    end
  end

  # the projectile the client renders for the swing (0 when none)
  defp attack_magic_path_id(attack) do
    case get_in(attack || %{}, [:magic_path_id]) do
      id when is_integer(id) and id > 0 -> id
      _ -> 0
    end
  end

  # whether the projectile homes to its target (the attack's arrow overlap)
  defp attack_arrow_overlap?(attack) do
    get_in(attack || %{}, [:arrow, :overlap]) == true
  end

  # the hit's reach: the firing attack's range, falling back to the mob's
  # stop range so the re-check stays meaningful
  defp attack_range(attack, npc) do
    case get_in(attack || %{}, [:range, :distance]) do
      range when is_number(range) and range > 0 -> range * 1.0
      _ -> stop_range(npc)
    end
  end

  # the attack's damage rate (scales the mob's attack stat)
  defp attack_rate(attack) do
    case get_in(attack || %{}, [:damage, :rate]) do
      rate when is_number(rate) -> rate * 1.0
      _ -> 1.0
    end
  end

  # the swing's cast timing from the motion timeline: the cast spans every
  # motion's playback and the hit lands at the firing attack's animation
  # keyframe — the moment the swing actually releases — falling back to 40%
  # into the firing motion when the model carries no keyframe timing
  defp cast_timing(npc, level_doc, motions, attack_motion_index, attack) do
    if is_list(motions) and motions != [] and Enum.all?(motions, & &1) do
      total = motions |> Enum.map(& &1.ms) |> Enum.sum()

      before =
        motions
        |> Enum.take(attack_motion_index)
        |> Enum.map(& &1.ms)
        |> Enum.sum()

      firing = Enum.at(motions, attack_motion_index) || List.last(motions)

      key_offset = key_offset_ms(npc, level_doc, attack_motion_index, attack)

      hit_offset =
        case key_offset do
          ms when is_number(ms) -> before + ms
          _ -> before + trunc(firing.ms * @hit_point_fraction)
        end

      {hit_offset, total}
    else
      {trunc(@fallback_duration_ms * @hit_point_fraction), @fallback_duration_ms}
    end
  end

  # when each later motion's sequence takes over the model: its start
  # offset within the swing (the first motion plays from the cast start)
  defp motion_switches(motions) do
    if is_list(motions) and motions != [] and Enum.all?(motions, & &1) do
      {switches, _total} =
        Enum.map_reduce(motions, 0, fn motion, elapsed ->
          {{elapsed, motion.sequence_id}, elapsed + motion.ms}
        end)

      Enum.drop(switches, 1)
    else
      []
    end
  end

  # the projectile's flight time to the target: the first magic-path
  # segment's velocity over the launch distance. Zero when the attack
  # fires no projectile (melee swings, ground indicators) or the path
  # carries no velocity — the hit then lands at the keyframe itself
  defp projectile_travel_ms(magic_path_id, from, to) do
    segments =
      if magic_path_id > 0 do
        Storage.Table.MagicPaths.get(magic_path_id) || []
      else
        []
      end

    case segments do
      [segment | _] when is_map(segment) ->
        velocity = segment[:velocity]

        if is_number(velocity) and velocity > 0 do
          distance = :math.sqrt(square_distance(from, to))
          flight = min(distance, segment[:distance] || distance)
          trunc(flight / velocity * 1000)
        else
          0
        end

      _ ->
        0
    end
  end

  # the firing attack's keyframe time within its motion's sequence, in ms
  defp key_offset_ms(npc, level_doc, attack_motion_index, attack) do
    model = get_in(npc.npc.metadata, [:model, :name])
    point_name = attack_point_name(attack)

    seq_name =
      level_doc
      |> get_in([:motions])
      |> List.wrap()
      |> Enum.at(attack_motion_index)
      |> case do
        motion when is_map(motion) -> get_in(motion, [:motion_property, :sequence_name])
        _ -> nil
      end

    case Storage.Animations.key_time(model, seq_name, point_name) do
      seconds when is_number(seconds) -> trunc(seconds * 1000)
      _ -> nil
    end
  end

  defp start_running(npc) do
    run = sequence_id(npc, "Run_A") || sequence_id(npc, "Walk_A")

    case run do
      nil -> npc
      id when id == npc.animation -> npc
      id -> %{npc | animation: id, send_control?: true}
    end
  end

  # actors face along their move direction: yaw from the horizontal
  # direction, degrees. With the front axis stored negated in the transform
  # (M21 = -x, M22 = -y), a direction (dx, dy) yields yaw = atan2(dx, -dy).
  # A zero-length direction keeps the current heading
  defp face_toward(%Types.Coord{} = from, %Types.Coord{} = to, current) do
    dx = to.x - from.x
    dy = to.y - from.y

    if dx == 0 and dy == 0 do
      current
    else
      yaw = :math.atan2(dx, -dy) * 180 / :math.pi()
      %{current | z: yaw}
    end
  end

  defp step_toward(position, target, budget, speed) do
    dx = target.x - position.x
    dy = target.y - position.y
    dz = target.z - position.z
    dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist <= budget do
      arrived = %Types.Coord{x: target.x, y: target.y, z: target.z}

      %{kind: :arrived, position: arrived, velocity: {0.0, 0.0, 0.0}, leftover: budget - dist}
    else
      ux = dx / dist
      uy = dy / dist
      uz = dz / dist

      moved = %Types.Coord{
        x: position.x + ux * budget,
        y: position.y + uy * budget,
        z: position.z + uz * budget
      }

      %{
        kind: :moving,
        position: moved,
        velocity: {ux * speed, uy * speed, uz * speed},
        leftover: 0
      }
    end
  end

  defp square(v) when is_number(v), do: v * v

  # full 3D squared distance: range checks are height-sensitive, so a mob
  # standing below a ledge is not "in range" of what is on top of it
  defp square_distance(%Types.Coord{} = a, %Types.Coord{} = b) do
    dx = a.x - b.x
    dy = a.y - b.y
    dz = a.z - b.z
    dx * dx + dy * dy + dz * dz
  end

  defp sight_bands(npc) do
    distance = get_in(npc.npc.metadata, [:distance]) || %{}

    %{
      sight: Map.get(distance, :sight, 0),
      height_up: Map.get(distance, :sight_height_up, 0),
      height_down: Map.get(distance, :sight_height_down, 0),
      last_sight: Map.get(distance, :last_sight_radius, 0),
      last_height_up: Map.get(distance, :last_sight_height_up, 0),
      last_height_down: Map.get(distance, :last_sight_height_down, 0)
    }
  end

  # the mob closes to its first attack's range before stopping; mobs without
  # usable attack metadata walk up to melee contact instead
  defp stop_range(npc) do
    case attack_range(npc) do
      range when is_number(range) and range > 0 -> range * 1.0
      _ -> melee_range(npc)
    end
  end

  # the range the mob closes to before swinging: the firing attack's reach
  defp attack_range(npc) do
    case get_in(npc.npc.metadata, [:skill]) do
      [%{id: skill_id, level: level} | _] ->
        with %{levels: levels} <- Storage.Skills.get_meta(skill_id),
             level_doc when is_map(level_doc) <- levels[to_string(level)],
             {_index, attack} when is_map(attack) <- swing_attack(level_doc) do
          get_in(attack, [:range, :distance])
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp melee_range(npc) do
    radius = get_in(npc.npc.metadata, [:capsule, :radius]) || 0
    max(radius + 80, 120)
  end

  defp sequence_id(npc, name) do
    Storage.Animations.sequence_id(get_in(npc.npc.metadata, [:model, :name]), name)
  end
end
