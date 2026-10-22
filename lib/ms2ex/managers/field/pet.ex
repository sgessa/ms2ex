defmodule Ms2ex.Managers.Field.Pet do
  @moduledoc """
  Summoned pets on the field: the control stream and the follow behavior.

  Pets ride the same npc control machinery (dirty-flag entries in
  ControlNpc, spawned and animated by the client from that stream) and
  move through the battle chase engine with attacks disabled: a navmesh
  trace inside the mid band, a stand inside the near band, a stand beyond
  the far band, a warp to the owner beyond the pet's metadata warp
  distance, and a warp once an unreachable owner (platforms, ledges)
  defeats the pathing for a grace period. Near the owner the pet runs its
  idle routine — stands, bore emotes and small roam legs around the
  owner's position — from the action weights its npc metadata carries.
  """

  alias Ms2ex.Managers.Field
  alias Ms2ex.Managers.Field.Npc.Movement
  alias Ms2ex.Managers.Field.Npc.Patrol
  alias Ms2ex.Navigation
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  # controls go out on change only; a fixed fast cadence makes the client
  # re-apply the sequence and flap between walk and idle
  #
  # follow bands from the pet AI script (AI_DefaultPetTaming preset
  # default): trace the owner inside the far band, stand inside the near
  # band, stand (give up) beyond the far band
  @pet_far_distance 1000.0
  @pet_near_distance 100.0
  # a standing pet only resumes the chase once the owner clearly pulls
  # away, so it cannot flip run/idle at the near-band edge
  @pet_resume_margin 60.0
  # an unreachable owner (ledges, platforms — no navmesh route) warps the
  # pet over after this grace: retail pets "occasionally teleport" when
  # separation or terrain defeats the pathing
  @pet_stuck_warp_ms 3000
  # reachability probe cadence (shares the battle map's repath clock)
  @pet_probe_ms 500

  # a roam leg completes once the pet is this close to its goal
  # (the battle wander arrival range)
  @pet_roam_arrive_range 30

  # a stand holds for about this long before the next routine is rolled
  @pet_stand_ms 1_000
  # a bore emote without a recorded beat plays for this long
  @pet_emote_fallback_ms 4_000

  # -- control stream ------------------------------------------------------------

  @doc """
  The field-registration attributes for a character's summoned pet: the
  npc actor resolved from the pet metadata, anchored on the owner.
  """
  def spawn_attrs(%{item: item, pet: metadata}, character) do
    npc_metadata = Storage.Npcs.get_meta(metadata.npc_id)

    [
      item: item,
      npc: Types.Npc.new(%{id: metadata.npc_id, metadata: npc_metadata}),
      pet: metadata,
      owner_character_id: character.id,
      owner_object_id: character.object_id,
      position: character.position,
      rotation: character.rotation,
      map_id: character.map_id,
      # TODO badge pet-skin override
      skin_id: metadata.npc_id
    ]
  end

  def tick(state) do
    now = Ms2ex.sync_ticks()

    case Map.get(state, :pets, %{}) do
      empty when empty == %{} ->
        state

      pets ->
        {pets, views} = tick_pet_controls(pets, state, now)
        state = %{state | pets: pets}

        # single-entry controls: the client mishandles multi-entry batches
        # (same constraint the npc keepalive works around)
        for view <- views do
          Field.broadcast(state.topic, Packets.ControlNpc.bytes([view]))
        end

        state
    end
  end

  defp tick_pet_controls(pets, state, now) do
    {entries, views} =
      Enum.flat_map_reduce(pets, [], fn {object_id, pet}, views ->
        {pet, _hits} = follow(pet, pet.owner_character_id, state, now)

        if pet.send_control? do
          pet = %{pet | seq_counter: pet.seq_counter + 1, send_control?: false}
          {[{object_id, pet}], [control_view(pet) | views]}
        else
          {[{object_id, pet}], views}
        end
      end)

    {Map.new(entries), views}
  end

  # ControlNpc entries are written from the npc actor shape; a pet maps
  # onto it with its own position, the idle sequence and no battle state
  def control_view(pet) do
    %Types.FieldNpc{
      object_id: pet.object_id,
      npc: pet.npc,
      position: pet.position,
      rotation: pet.rotation,
      velocity: pet.velocity,
      animation: pet.animation,
      seq_counter: pet.seq_counter,
      dead?: false
    }
  end

  # -- follow --------------------------------------------------------------------

  @doc """
  Pet follow, per the pet AI script (AI_DefaultPetTaming preset default)
  plus the pet metadata warp distance and the retail stuck warp.
  """
  def follow(npc, target_id, field_state, now) do
    battle = npc.battle || follow_battle(target_id, now)
    target_position = get_in(field_state, [:player_positions, target_id, :position])

    cond do
      is_nil(target_position) ->
        {npc, []}

      square_distance(npc.position, target_position) > square(warp_distance(npc)) ->
        {warp_to_owner(npc, battle, target_position, now), []}

      true ->
        {stuck?, battle} = probe_stuck(npc, battle, target_position, now)
        npc = %{npc | battle: battle}
        follow_band(npc, battle, target_position, now, stuck?)
    end
  end

  defp follow_band(npc, battle, target_position, now, stuck?) do
    cond do
      stuck? ->
        {warp_to_owner(npc, battle, target_position, now), []}

      square_distance(npc.position, target_position) > square(@pet_far_distance) ->
        {Movement.stand(npc, battle, target_position, now), []}

      # an active roam leg: walk it to its goal, but the owner leaving the
      # near band breaks it off — the chase comes first
      battle.mode == :wander ->
        if square_distance(npc.position, target_position) >
             square(@pet_near_distance + @pet_resume_margin) do
          battle = %{battle | mode: :chase}
          npc = %{npc | battle: battle, idle: nil}
          Movement.walk_chase_route(npc, battle, target_position, now)
        else
          roam_tick(npc, battle, now)
        end

      # near-band stand with the chase's resume hysteresis: a running pet
      # closes into the band before stopping, and a standing pet only
      # resumes once the owner clearly pulls away
      square_distance(npc.position, target_position) < square(@pet_near_distance) ->
        idle_near_owner(npc, battle, target_position, now)

      npc.velocity == {0, 0, 0} and
          square_distance(npc.position, target_position) <
            square(@pet_near_distance + @pet_resume_margin) ->
        idle_near_owner(npc, battle, target_position, now)

      true ->
        Movement.walk_chase_route(npc, battle, target_position, now)
    end
  end

  # unreachability probe on the repath cadence: a pet whose owner has no
  # walkable route (fully or partially — a ledge with ground under it
  # partials) warps over once the grace elapses; a healthy route clears
  # the stamp. the distance warp check above skips the probe — it warps
  # regardless
  defp probe_stuck(npc, battle, target_position, now) do
    case battle.no_route_since do
      since when is_integer(since) ->
        if now - since >= @pet_stuck_warp_ms do
          reachable?(npc, battle, target_position, now)
        else
          {false, battle}
        end

      nil ->
        if now >= battle.next_repath_at do
          reachable?(npc, battle, target_position, now)
        else
          {false, battle}
        end
    end
  end

  defp reachable?(npc, battle, target_position, now) do
    battle = %{battle | next_repath_at: now + @pet_probe_ms}

    case Navigation.find_path(npc.map_id, npc.position, target_position) do
      {:ok, _path} ->
        {false, %{battle | no_route_since: nil}}

      _unreachable ->
        # still no route once the grace elapsed: warp (and keep the stamp
        # so an owner camped on an unreachable ledge doesn't re-probe
        # every tick — warp_to_owner resets it)
        if battle.no_route_since && now - battle.no_route_since >= @pet_stuck_warp_ms do
          {true, battle}
        else
          {false, %{battle | no_route_since: battle.no_route_since || now}}
        end
    end
  end

  defp warp_distance(npc) do
    warp = get_in(npc.pet, [:distances, :warp])
    if is_number(warp) and warp > 0, do: warp * 1.0, else: @pet_far_distance
  end

  # the separation warp: the pet re-appears on the floor under its owner
  # (movement rides the mesh or it does not happen), the stale route is
  # dropped and the control carries the new position
  defp warp_to_owner(npc, battle, target_position, now) do
    position =
      case Navigation.snap_to_floor(npc.map_id, target_position) do
        nil -> target_position
        snapped -> snapped
      end

    idle = idle_sequence_id(npc) || npc.animation

    %{
      npc
      | position: position,
        velocity: {0, 0, 0},
        animation: idle,
        idle: nil,
        battle: %{
          battle
          | path: nil,
            path_index: 1,
            goal: nil,
            next_repath_at: now + @pet_probe_ms,
            last_move_at: now,
            no_route_since: nil
        },
        send_control?: true
    }
  end

  defp follow_battle(target_id, now) do
    %{
      mode: :chase,
      target_id: target_id,
      stop_range: @pet_near_distance,
      cast: nil,
      swing_until: nil,
      attack_counter: 0,
      path: nil,
      path_index: 1,
      goal: nil,
      next_repath_at: 0,
      last_move_at: now,
      no_route_since: nil
    }
  end

  # -- near-owner idle roam ---------------------------------------------------------
  # the pet's action metadata carries the npc idle routine weights
  # (Idle_A/Walk_A/Bore_A, move_area): near the owner it stands, plays
  # bore emotes and roams small legs around the owner's position — the
  # same beat structure the mob Idle module runs around a spawn point

  defp idle_near_owner(npc, battle, target_position, now) do
    case npc.idle do
      %{task: :wander, goal: goal} ->
        roam_tick(npc, %{battle | mode: :wander, goal: goal}, now)

      %{task: task, until: until} when task in [:stand, :emote] and now < until ->
        {npc, []}

      _ ->
        pick_routine(npc, battle, target_position, now)
    end
  end

  defp roam_tick(npc, battle, now) do
    if square_distance(npc.position, battle.goal) < square(@pet_roam_arrive_range) do
      {%{
         npc
         | battle: nil,
           velocity: {0, 0, 0},
           idle: %{task: :stand, until: now + @pet_stand_ms},
           send_control?: true
       }, []}
    else
      Movement.walk_chase_route(npc, battle, battle.goal, now)
    end
  end

  defp pick_routine(npc, battle, target_position, now) do
    case weighted_routine(npc) do
      routine when is_binary(routine) ->
        cond do
          String.contains?(routine, "Bore_") ->
            start_pet_emote(npc, routine, now)

          String.starts_with?(routine, "Walk_") or String.starts_with?(routine, "Run_") ->
            start_roam(npc, battle, target_position, routine, now)

          # Idle_* and unknown routines keep the pet at its post
          true ->
            start_pet_stand(npc, now)
        end

      _ ->
        start_pet_stand(npc, now)
    end
  end

  defp weighted_routine(npc) do
    actions = get_in(npc.npc.metadata, [:action, :actions]) || []
    total = Enum.reduce(actions, 0, &(&1.probability + &2))
    if total > 0, do: roll_routine(actions, :rand.uniform(total))
  end

  defp roll_routine(actions, roll) do
    Enum.reduce_while(actions, 0, fn action, acc ->
      if acc + action.probability >= roll do
        {:halt, action.name}
      else
        {:cont, acc + action.probability}
      end
    end)
  end

  defp start_pet_stand(npc, now) do
    animation = idle_sequence_id(npc) || npc.animation

    if npc.animation == animation and npc.velocity == {0, 0, 0} do
      %{npc | idle: %{task: :stand, until: now + @pet_stand_ms}}
    else
      %{
        npc
        | idle: %{task: :stand, until: now + @pet_stand_ms},
          animation: animation,
          velocity: {0, 0, 0},
          send_control?: true
      }
    end
  end

  defp start_pet_emote(npc, routine, now) do
    model = get_in(npc.npc.metadata, [:model, :name])

    with id when is_integer(id) <- Storage.Animations.sequence_id(model, routine),
         ms when is_integer(ms) and ms > 0 <- pet_emote_ms(model, routine) do
      {%{npc | animation: id, idle: %{task: :emote, until: now + ms}, send_control?: true}, []}
    else
      _ -> start_pet_stand(npc, now)
    end
  end

  defp pet_emote_ms(model, routine) do
    case Storage.Animations.sequence_time(model, routine) do
      seconds when is_number(seconds) and seconds > 0 -> trunc(seconds * 1000)
      _ -> @pet_emote_fallback_ms
    end
  end

  # a roam leg: a random walkable point inside the move area around the
  # owner (not a fixed anchor — the owner is the pet's home), walked at
  # the routine's gait
  defp start_roam(npc, battle, target_position, routine, now) do
    move_area = get_in(npc.npc.metadata, [:action, :move_area]) || 0

    if move_area > 0 and Patrol.npc_speed(npc, :walk_speed) > 0.0 do
      case Navigation.random_point_around(npc.map_id, target_position, move_area) do
        nil ->
          start_pet_stand(npc, now)

        goal ->
          model = get_in(npc.npc.metadata, [:model, :name])
          animation = Storage.Animations.sequence_id(model, routine) || npc.animation

          battle = %{
            battle
            | mode: :wander,
              goal: goal,
              path: nil,
              path_index: 1,
              next_repath_at: 0,
              last_move_at: now
          }

          npc = %{npc | idle: %{task: :wander, goal: goal}, battle: battle, animation: animation}

          Movement.walk_chase_route(npc, battle, goal, now)
      end
    else
      start_pet_stand(npc, now)
    end
  end

  # -- shared helpers -----------------------------------------------------------

  defp square_distance(%Types.Coord{} = from, %Types.Coord{} = to) do
    dx = to.x - from.x
    dy = to.y - from.y
    dz = to.z - from.z
    dx * dx + dy * dy + dz * dz
  end

  defp square(value) when is_number(value), do: value * value

  defp idle_sequence_id(npc) do
    model = get_in(npc.npc.metadata, [:model, :name])
    Storage.Animations.sequence_id(model, "Idle_A")
  end
end
