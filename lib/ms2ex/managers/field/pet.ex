defmodule Ms2ex.Managers.Field.Pet do
  @moduledoc """
  Summoned pets on the field: the control stream and the follow behavior.

  Pets ride the same npc control machinery (dirty-flag entries in
  ControlNpc, spawned and animated by the client from that stream) and
  move through the battle chase engine with attacks disabled: a navmesh
  trace inside the mid band, a stand inside the near band, a stand beyond
  the far band, a warp to the owner beyond the pet's metadata warp
  distance, and a warp once an unreachable owner (platforms, ledges)
  defeats the pathing for a grace period. Inside the near band the pet
  stands at its owner's side.
  """

  alias Ms2ex.Managers.Field
  alias Ms2ex.Managers.Field.Npc.Movement
  alias Ms2ex.Navigation
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  # taming: points come from taming-skill hits (pet_taming.taming_point,
  # e.g. the taming candy's 1000) and decay once a second from ANY gauge —
  # a full gauge drains too, so the capture window after the last hit is
  # bounded (retail: "place the trap quickly")
  @taming_decay_ms 1_000
  @taming_decay_points 200
  # the gauge at which a pet is capturable and behaves tame (approaches the
  # tamer); below it the pet reverts to skittish wandering
  @capture_gauge 8_500
  # an un-tamed wild pet despawns after this long without a taming hit
  # (the decay holds last_tame_at fresh while it drains, so the window
  # runs from the last activity); capturable pets wait for their snare
  @wild_pet_ttl_ms 60_000

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
        pets = decay_taming_points(pets, state, now)
        {pets, expired} = expire_abandoned_pets(pets, now)

        state =
          if expired == [], do: state, else: Field.despawn_wild_pets(state, expired)

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
        {pet, _hits} =
          if pet.owner_character_id do
            follow(pet, pet.owner_character_id, state, now)
          else
            wild_ai(pet, state, now)
          end

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

  # -- wild pets -------------------------------------------------------------------

  @doc """
  Spawns a wild pet on field state: no owner, a taming rank roll, and no
  battle AI (wild pets never damage players — they are the taming target).
  State-in/state-out; broadcasts the add.
  """
  def spawn_wild(state, pet_id, npc_id, position) do
    case Storage.Pets.get_meta(pet_id) do
      %{} = metadata ->
        npc_id = metadata.npc_id || npc_id

        case Storage.Npcs.get_meta(npc_id) do
          %{} = npc_metadata ->
            pet_attrs = [
              item: nil,
              npc: Types.Npc.new(%{id: npc_id, metadata: npc_metadata}),
              pet: metadata,
              position: position,
              rotation: struct(Types.Coord, %{}),
              # pathing and floor-snapping resolve against the field's mesh
              map_id: state.map_id,
              skin_id: npc_id,
              taming_rank: :rand.uniform(100)
            ]

            {field_pet, state} = Field.register_pet(pet_attrs, state)
            {:ok, field_pet, state}

          nil ->
            {:error, state}
        end

      nil ->
        {:error, state}
    end
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

      # TODO near-owner idle roam (stands, bore emotes, small wander legs)
      # was removed — it needs a reliable roam-goal picker before it reads
      # as anything but the pet wandering off. The near band is a plain
      # stand, with the chase's resume hysteresis: a running pet closes
      # into the band before stopping, and a standing pet only resumes
      # once the owner clearly pulls away
      square_distance(npc.position, target_position) < square(@pet_near_distance) ->
        {Movement.stand(npc, battle, target_position, now), []}

      npc.velocity == {0, 0, 0} and
          square_distance(npc.position, target_position) <
            square(@pet_near_distance + @pet_resume_margin) ->
        {Movement.stand(npc, battle, target_position, now), []}

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

  # taming points decay 100/s a second after the last taming hit (the
  # reference's decay cadence); each decay step re-announces the points so
  # the client's pet window stays honest
  defp decay_taming_points(pets, state, now) do
    Map.new(pets, fn {object_id, %Types.FieldPet{} = pet} ->
      if pet.taming_points > 0 and now - pet.last_tame_at >= @taming_decay_ms do
        points = max(pet.taming_points - @taming_decay_points, 0)
        pet = %{pet | taming_points: points, last_tame_at: now}

        Field.broadcast(
          state.topic,
          Packets.SyncPetTamingPoint.bytes(pet, 0, points)
        )

        {object_id, pet}
      else
        {object_id, pet}
      end
    end)
  end

  defp taming_max_point do
    case Storage.Tables.Constants.get(:taming_pet_max_point) do
      n when is_integer(n) and n > 0 -> n
      _ -> 10_000
    end
  end

  # un-tamed wild pets despawn after the TTL without a taming hit: an
  # abandoned pet holds its spawn point's population slot forever otherwise,
  # and the spawn stops rolling new pets. Ready pets are exempt — they wait
  # for their snare while capturable. Returns {remaining pets, expired actors}.
  defp expire_abandoned_pets(pets, now) do
    {expired, remaining} =
      Map.split_with(pets, fn {_object_id, %Types.FieldPet{} = pet} ->
        pet.owner_character_id == nil and
          pet.taming_points < @capture_gauge and
          now - pet.last_tame_at >= @wild_pet_ttl_ms
      end)

    {remaining, Map.values(expired)}
  end

  @doc "Applies a taming hit to a wild pet; caps at the ready threshold."
  def apply_taming_hit(state, object_id, caster_object_id, points, now) do
    case Map.get(state.pets, object_id) do
      %Types.FieldPet{owner_character_id: nil} = pet ->
        max_point = taming_max_point()
        new_points = min(pet.taming_points + points, max_point)
        pet = %{pet | taming_points: new_points, last_tame_at: now}

        Field.broadcast(
          state.topic,
          Packets.SyncPetTamingPoint.bytes(pet, caster_object_id, new_points)
        )

        state = put_in(state, [:pets, object_id], pet)
        {:ready, new_points == max_point, state}

      _ ->
        {:miss, state}
    end
  end

  @doc """
  A snare (trap skill) hit captures a wild pet at or above the capture
  gauge — below it the snare fails and only re-announces the gauge.
  """
  def apply_snare_hit(state, object_id, caster_object_id) do
    case Map.get(state.pets, object_id) do
      %Types.FieldPet{owner_character_id: nil} = pet ->
        if pet.taming_points >= @capture_gauge do
          Field.broadcast(
            state.topic,
            Packets.SyncPetTamingPoint.bytes(pet, caster_object_id, pet.taming_points)
          )

          {{:captured, pet}, state}
        else
          Field.broadcast(
            state.topic,
            Packets.SyncPetTamingPoint.bytes(pet, caster_object_id, pet.taming_points)
          )

          {:not_ready, state}
        end

      _ ->
        {:miss, state}
    end
  end

  # -- wild pet AI ---------------------------------------------------------------
  # AI_DefaultPetTaming's wild cascade: behavior presets key off the taming
  # gauge. A low gauge is a skittish wanderer (runaway hops around the nearest
  # player, occasional short approach legs); a fed pet calms to standing; a
  # nearly-full gauge approaches but backs off inside the band; a full gauge
  # traces to the player and holds — the "come here for the snare" posture.
  # The script ties no behavior to the hit itself: the flee-ish feel comes
  # from the runaway weights while the gauge is low.

  # gauge thresholds: the script's cascade, re-banded around the capture
  # gauge (the pet stays tame and close for the whole capture window)
  @gauge_calm 3000

  # distance bands from the script's conditions
  @close_band 300
  @far_band 1000
  @arrive_band 80
  @runaway_length 450
  # a capturable pet stands inside the snare's reach (the trap skill's
  # region), not at the script's 400-unit trace distance
  @trace_hold_band 150

  # the script's node limits (100-2000ms), condensed
  @idle_stand_ms 2000
  @trace_leg_ms 300
  @runaway_leg_ms 1200
  @stand_min_ms 500
  @stand_max_ms 1100

  @doc """
  One wild-pet AI step: picks the behavior preset from the taming gauge and
  advances the current action (pathed walk legs and stands) through the
  shared movement engine. State-in/state-out like `follow/4`.
  """
  def wild_ai(pet, state, now) do
    ai = pet.wild_ai || %{action: nil}

    case nearest_player(pet, state) do
      nil ->
        # nothing to react to: hold (the script's standbys face a target;
        # without one the pet keeps its heading)
        pet = Movement.stand(pet, battle(pet, now), pet.position, now)
        {%{pet | wild_ai: %{action: nil}}, []}

      target ->
        {_character_id, _object_id, target_position} = target
        mode = mode_for(pet.taming_points)
        {ai, pet} = wild_step(mode, ai, pet, target_position, now)
        {%{pet | wild_ai: ai}, []}
    end
  end

  defp mode_for(points) when points >= @capture_gauge, do: :trace
  defp mode_for(points) when points >= @gauge_calm, do: :idle
  defp mode_for(_points), do: :wander

  # capture window: approach and hold inside the snare's reach
  defp wild_step(:trace, ai, pet, target_position, now) do
    if square_distance(pet.position, target_position) > square(@trace_hold_band) do
      {ai, approach(pet, target_position, now)}
    else
      {ai, Movement.stand(pet, battle(pet, now), target_position, now)}
    end
  end

  defp wild_step(mode, ai, pet, target_position, now) do
    paced_step(mode, ai, pet, target_position, now)
  end

  # actions with a duration: walk legs expire or arrive, stands expire; past
  # that the mode's weighted table picks the next move
  defp paced_step(mode, ai, pet, target_position, now) do
    action =
      case ai.action do
        {:walk, goal, until} ->
          if now < until and not arrived?(pet, goal) do
            {:walk, goal, until}
          else
            decide_action(mode, pet, target_position, now)
          end

        {:stand, face, until} ->
          if now < until do
            {:stand, face, until}
          else
            decide_action(mode, pet, target_position, now)
          end

        nil ->
          decide_action(mode, pet, target_position, now)
      end

    pet = apply_action(pet, action, now)
    {%{ai | action: action}, pet}
  end

  # the script's select tables, condensed: {runaway, trace, standby} weights
  defp weights(:idle, _dist_sq), do: {0, 25, 75}

  defp weights(:wander, dist_sq) do
    cond do
      dist_sq > square(@far_band) -> {0, 0, 100}
      dist_sq < square(@close_band) -> {70, 20, 10}
      true -> {60, 30, 10}
    end
  end

  defp decide_action(mode, pet, target_position, now) do
    {away, trace, stand} = weights(mode, square_distance(pet.position, target_position))
    roll = :rand.uniform(max(away + trace + stand, 1))

    cond do
      roll <= away ->
        {:walk, away_goal(pet, target_position), now + @runaway_leg_ms}

      roll <= away + trace ->
        {:walk, trace_goal(pet, target_position), now + @trace_leg_ms}

      mode == :idle ->
        {:stand, target_position, now + @idle_stand_ms}

      true ->
        {:stand, target_position,
         now + @stand_min_ms + :rand.uniform(@stand_max_ms - @stand_min_ms)}
    end
  end

  defp apply_action(pet, {:walk, goal, _until}, now) do
    {pet, _} = Movement.walk_chase_route(pet, battle(pet, now), goal, now)
    pet
  end

  defp apply_action(pet, {:stand, face, _until}, now) do
    Movement.stand(pet, battle(pet, now), face, now)
  end

  defp approach(pet, target_position, now) do
    {pet, _} = Movement.walk_chase_route(pet, battle(pet, now), target_position, now)
    pet
  end

  defp arrived?(pet, goal) do
    square_distance(pet.position, goal) < square(@arrive_band)
  end

  defp away_goal(pet, target_position) do
    dx = pet.position.x - target_position.x
    dy = pet.position.y - target_position.y

    {ux, uy} =
      if dx == 0 and dy == 0 do
        angle = :rand.uniform() * 2 * :math.pi()
        {:math.cos(angle), :math.sin(angle)}
      else
        len = :math.sqrt(dx * dx + dy * dy)
        {dx / len, dy / len}
      end

    goal = %Types.Coord{
      x: pet.position.x + ux * @runaway_length,
      y: pet.position.y + uy * @runaway_length,
      z: pet.position.z
    }

    snap_goal(pet, goal)
  end

  # trace legs are short steps toward the target (the script's trace nodes
  # run till=100-300ms), never the full closing distance
  defp trace_goal(pet, target_position) do
    dx = target_position.x - pet.position.x
    dy = target_position.y - pet.position.y

    if dx == 0 and dy == 0 do
      pet.position
    else
      len = :math.sqrt(dx * dx + dy * dy)
      step = min(len, @runaway_length / 2)

      goal = %Types.Coord{
        x: pet.position.x + dx / len * step,
        y: pet.position.y + dy / len * step,
        z: pet.position.z
      }

      snap_goal(pet, goal)
    end
  end

  defp snap_goal(pet, goal) do
    case Navigation.snap_to_floor(pet.map_id, goal) do
      nil -> goal
      snapped -> snapped
    end
  end

  # the nearest live player on the field: the script's distance conditions
  # reference the AI target, which for a wild pet is whoever is closest
  defp nearest_player(pet, state) do
    dead = Map.get(state, :tombstones, %{})

    state.players
    |> Enum.reject(fn {character_id, _object_id} -> Map.has_key?(dead, character_id) end)
    |> Enum.flat_map(fn {character_id, object_id} ->
      case get_in(state, [:player_positions, character_id, :position]) do
        %Types.Coord{} = position -> [{character_id, object_id, position}]
        _ -> []
      end
    end)
    |> Enum.min_by(
      fn {_character_id, _object_id, position} -> square_distance(pet.position, position) end,
      fn -> nil end
    )
  end

  defp battle(pet, now), do: pet.battle || follow_battle(0, now)

  @doc """
  Forced taming captures the wild pet regardless of its gauge (the
  reference's ForcedTaming items skip the readiness requirement).
  """
  def apply_forced_capture(state, object_id) do
    case Map.get(state.pets, object_id) do
      %Types.FieldPet{owner_character_id: nil} = pet ->
        Field.broadcast(
          state.topic,
          Packets.SyncPetTamingPoint.bytes(pet, 0, pet.taming_points)
        )

        {{:captured, pet}, state}

      _ ->
        {:miss, state}
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
