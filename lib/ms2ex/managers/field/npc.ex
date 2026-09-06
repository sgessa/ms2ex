defmodule Ms2ex.Managers.Field.Npc do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types
  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Types.SkillCast

  # animation transitions keep dirtying npcs on live servers, so even idle
  # ones re-announce themselves every few seconds; this also covers the
  # client dropping controls sent while it asynchronously loads the entity
  @idle_control_ms 30
  @corpse_broadcast_ms 1000
  @spawn_rate_ms 1000
  @force_spawn_multiplier 2

  def load_npc_spawns(state) do
    state.map_id
    |> Storage.Maps.get_npc_spawns()
    |> Enum.each(fn npc_spawn ->
      npc_ids =
        npc_spawn.npc_list
        |> Enum.map(&List.duplicate([&1.npc_id], &1.count))
        |> List.flatten()

      send(self(), {:add_npc_spawn, npc_spawn, npc_ids})
    end)
  end

  def load_mob_spawns(state) do
    state.map_id
    |> Storage.Maps.get_mob_spawns()
    |> Enum.each(fn mob_spawn ->
      send(self(), {:add_npc_spawn, mob_spawn, mob_spawn.npc_ids})
    end)
  end

  def load_spawn(state, npc_spawn, npc_ids) do
    {spawn_point_id, state} = Managers.Field.next_local_id(state)

    npc_spawn =
      npc_spawn
      |> Map.put(:id, spawn_point_id)
      |> Map.put(:spawned_mobs, [])
      |> Map.put(:spawned_npcs, [])

    state = put_in(state, [:npc_spawns, spawn_point_id], npc_spawn)

    # on script-controlled maps the trigger scripts own npc appearances:
    # only what the running script spawns (spawn_monster) becomes visible
    script_controlled? = Map.get(state, :script_controlled_npcs, false)

    cond do
      script_controlled? ->
        put_in(state, [:npc_spawns, spawn_point_id, :spawn_tick], :infinity)

      mob_spawn?(npc_spawn) ->
        # mob spawn points fill their population through the tick-driven
        # spawn cycle; the first cycle is due as soon as the spawn is loaded
        spawn_tick =
          if npc_spawn[:on_field_create] == false, do: :infinity, else: Ms2ex.sync_ticks()

        put_in(state, [:npc_spawns, spawn_point_id, :spawn_tick], spawn_tick)

      npc_spawn[:on_field_create] != false ->
        # story npcs on field-create spawns appear immediately
        Enum.reduce(npc_ids, state, fn npc_id, state ->
          {:ok, state} = spawn_and_track(state, spawn_point_id, npc_id, npc_spawn)
          state
        end)

      true ->
        # story npcs that wait for a spawn_monster script action
        state
    end
  end

  defp spawn_and_track(state, spawn_point_id, npc_id, npc_spawn) do
    case spawn_npc(state, npc_id, npc_spawn) do
      {%Types.FieldNpc{} = field_npc, state} ->
        state =
          update_in(
            state,
            [:npc_spawns, spawn_point_id, :spawned_npcs],
            &[
              field_npc.object_id | &1
            ]
          )

        {:ok, state}

      {nil, state} ->
        {:error, state}
    end
  end

  # mob spawn documents carry a flat npc_ids list; friendly spawn points carry
  # npc_list entries instead
  defp mob_spawn?(npc_spawn), do: Map.has_key?(npc_spawn, :npc_ids)

  def load_npc(state, %Types.Npc{} = npc, npc_spawn) do
    {_field_npc, state} = spawn_npc(state, npc, npc_spawn)
    state
  end

  def load_npc(state, npc_id, npc_spawn) do
    {_field_npc, state} = spawn_npc(state, npc_id, npc_spawn)
    state
  end

  # Creates the field entity for an npc and announces it to clients. Returns
  # {nil, state} when the npc id has no metadata (nothing is spawned).
  def spawn_npc(state, npc_id, npc_spawn) when is_integer(npc_id) do
    case Storage.Npcs.get_meta(npc_id) do
      %{} = metadata ->
        npc = Types.Npc.new(%{id: npc_id, metadata: metadata})
        spawn_npc(state, npc, npc_spawn)

      _ ->
        {nil, state}
    end
  end

  def spawn_npc(state, %Types.Npc{} = npc, npc_spawn) do
    {object_id, state} = Managers.Field.next_local_id(state)

    field_npc =
      Types.FieldNpc.new(%{
        object_id: object_id,
        spawn_point_id: npc_spawn[:id],
        npc: npc,
        position: npc_spawn[:position],
        rotation: npc_spawn[:rotation],
        field: state.topic
      })

    Context.Field.broadcast(state.topic, Packets.FieldAddNpc.add_npc(field_npc))
    Context.Field.broadcast(state.topic, Packets.ProxyGameObj.load_npc(field_npc))

    {field_npc, put_in(state, [:npcs, object_id], field_npc)}
  end

  # A mob death frees its population slot and schedules the next spawn cycle:
  # a spawn wiped down to zero mobs starts its cooldown, while a partial kill
  # (with no cycle pending) respawns at twice the cooldown. A zero cooldown
  # means the spawn point never refills.
  def despawn(state, %FieldNpc{} = field_npc) do
    case get_in(state, [:npc_spawns, field_npc.spawn_point_id]) do
      %{} = spawn when is_map_key(spawn, :npc_ids) ->
        spawned = List.delete(spawn.spawned_mobs, field_npc.object_id)
        spawn = %{spawn | spawned_mobs: spawned}
        put_in(state, [:npc_spawns, spawn.id], schedule_spawn(spawn))

      _ ->
        state
    end
  end

  defp schedule_spawn(%{regen_check_time: cooldown} = spawn) when cooldown <= 0, do: spawn

  defp schedule_spawn(spawn) do
    now = Ms2ex.sync_ticks()
    cooldown_ms = spawn.regen_check_time * @spawn_rate_ms

    cond do
      spawn.spawned_mobs == [] ->
        %{spawn | spawn_tick: min(spawn.spawn_tick, now + cooldown_ms)}

      spawn.spawn_tick == :infinity ->
        %{spawn | spawn_tick: now + cooldown_ms * @force_spawn_multiplier}

      true ->
        spawn
    end
  end

  def remove_npc(field_npc, state) do
    npcs = Map.delete(state.npcs, field_npc.object_id)
    %{state | npcs: npcs}
  end

  def damage(state, attacker, dmg, object_id) do
    case Map.get(state.npcs, object_id) do
      nil ->
        {:error, state}

      %FieldNpc{} = field_npc ->
        field_npc = tag_attackers(field_npc, attacker)

        cond do
          field_npc.dead? && field_npc.corpse? ->
            field_npc = %{field_npc | seq_counter: field_npc.seq_counter + 1}
            Context.Field.broadcast(state.topic, Packets.ControlNpc.corpse_hit(field_npc))
            Context.Mobs.drop_corpse_rewards(field_npc, attacker, state.map_id)
            {:ok, field_npc, put_in(state, [:npcs, object_id], field_npc)}

          field_npc.dead? ->
            {:ok, field_npc, state}

          true ->
            apply_live_damage(field_npc, dmg, state, object_id)
        end
    end
  end

  def apply_skill_effects(state, skill_cast, mob_id) do
    case Map.get(state.npcs, mob_id) do
      %FieldNpc{dead?: false} = mob ->
        skill_cast
        |> SkillCast.attack_skills()
        |> Enum.reject(&Map.get(&1, :has_splash, false))
        |> Enum.reduce(state, fn effect, state ->
          {_buff, state} =
            Managers.Field.Buff.add_mob_buff(
              skill_cast.caster,
              effect.id,
              effect.level,
              mob,
              state,
              Map.get(effect, :overlap_count, 0)
            )

          state
        end)

      _ ->
        state
    end
  end

  def tick(state) do
    now = System.monotonic_time(:millisecond)

    {npcs, {live_dirty, corpse_dirty}} =
      Enum.flat_map_reduce(state.npcs, {[], []}, fn {object_id, npc}, acc ->
        tick_npc(now, object_id, npc, acc)
      end)

    boss_target = state.players |> Map.values() |> List.first()

    for npc <- Enum.reverse(live_dirty) do
      Context.Field.broadcast(state.topic, Packets.ControlNpc.bytes([npc], boss_target))
    end

    for npc <- Enum.reverse(corpse_dirty) do
      Context.Field.broadcast(state.topic, Packets.ControlNpc.dead(npc))
    end

    %{state | npcs: Map.new(npcs)}
    |> tick_mob_spawns()
  end

  # Runs due spawn cycles for mob spawn points: every cycle fills the
  # population back up to full, choosing a random npc id per slot. Timed on
  # sync_ticks so scheduling never depends on the raw clock base.
  defp tick_mob_spawns(state) do
    now = Ms2ex.sync_ticks()

    state
    |> Map.get(:npc_spawns, %{})
    |> Enum.reduce(state, fn {spawn_point_id, spawn}, state ->
      if mob_spawn?(spawn) and now >= spawn.spawn_tick do
        spawn = %{spawn | spawn_tick: :infinity}
        {spawn, state} = spawn_missing_mobs(spawn, state)
        put_in(state, [:npc_spawns, spawn_point_id], spawn)
      else
        state
      end
    end)
  end

  # TODO: pet spawn roll (pet_spawn_rate) — pet metadata is not projected yet
  # A spawn point can be filled on demand by trigger scripts (spawn_monster):
  # spawn whatever the population is missing right away.
  def trigger_spawn(state, spawn_point_id) do
    Enum.reduce(state.npc_spawns, state, fn
      {spawn_id, %{spawn_point_id: spid} = spawn}, state when spid == spawn_point_id ->
        {spawn, state} = fill_spawn(spawn, state)
        put_in(state, [:npc_spawns, spawn_id], spawn)

      _spawn, state ->
        state
    end)
  end

  defp fill_spawn(%{npc_ids: _} = spawn, state), do: spawn_missing_mobs(spawn, state)

  # friendly story spawns track spawned_npcs and fill from their npc_list
  defp fill_spawn(spawn, state) do
    expanded =
      spawn.npc_list
      |> Enum.flat_map(&List.duplicate(&1.npc_id, &1.count))

    to_spawn = Enum.drop(expanded, length(Map.get(spawn, :spawned_npcs, [])))

    Enum.reduce(to_spawn, {spawn, state}, fn npc_id, {spawn, state} ->
      case spawn_and_track(state, spawn.id, npc_id, spawn) do
        {:ok, state} -> {Map.get(state.npc_spawns, spawn.id), state}
        {:error, state} -> {spawn, state}
      end
    end)
  end

  @follow_dummies %{male: 2_040_998, female: 2_040_999}
  @follow_speed 150

  # spawns the invisible follow-dummy that walks a patrol path while the
  # player's client walks the player behind it (scripted carry sequences).
  # the dummy plays the waypoints' approach animation so the client keeps
  # the following player in a grounded walking state
  def spawn_follow_dummy(state, character, waypoints, approach_animation) do
    npc_id = Map.fetch!(@follow_dummies, character.gender)

    case spawn_npc(state, npc_id, %{position: character.position, rotation: nil, id: nil}) do
      {%Types.FieldNpc{} = field_npc, state} ->
        # spawn_npc may randomize mob positions; the dummy must start
        # exactly on the player it carries
        animation = animation_id(npc_id, approach_animation)

        field_npc = %{
          field_npc
          | position: character.position,
            animation: animation || field_npc.animation,
            patrol: %{
              waypoints: waypoints,
              index: 0,
              speed: @follow_speed,
              last_at: System.monotonic_time(:millisecond)
            }
        }

        {field_npc, put_in(state, [:npcs, field_npc.object_id], field_npc)}

      {nil, state} ->
        {nil, state}
    end
  end

  defp animation_id(npc_id, sequence_name) do
    model =
      case Storage.Npcs.get_meta(npc_id) do
        %{model: %{name: name}} -> name
        _ -> nil
      end

    Storage.Animations.sequence_id(model, sequence_name) ||
      standard_animation_id(sequence_name)
  end

  # the follow dummies have no animation table of their own; humanoid
  # sequence ids are standardized across models, so resolve the common
  # locomotion names directly
  @standard_animations %{"Run_A" => 7, "Walk_A" => 0, "Idle_A" => 5}
  defp standard_animation_id(name), do: Map.get(@standard_animations, name)

  defp spawn_missing_mobs(spawn, state) do
    missing = spawn.population - length(spawn.spawned_mobs)

    Enum.reduce(1..max(missing, 0), {spawn, state}, fn _i, {spawn, state} ->
      case spawn_npc(state, Enum.random(spawn.npc_ids), spawn) do
        {%FieldNpc{} = field_npc, state} ->
          spawned = spawn.spawned_mobs ++ [field_npc.object_id]
          {%{spawn | spawned_mobs: spawned}, state}

        {nil, state} ->
          {spawn, state}
      end
    end)
  end

  defp tag_attackers(field_npc, attacker) do
    field_npc
    |> Map.put(:last_attacker, attacker)
    |> Map.put(:first_attacker, field_npc.first_attacker || attacker)
    |> Map.put(:damage_dealers, Map.put(field_npc.damage_dealers, attacker.id, attacker))
    # entering battle must reach clients on the next control tick so the
    # boss HP bar picks up the new target without waiting for idle cadence
    |> Map.put(:send_control?, true)
  end

  defp apply_live_damage(%FieldNpc{} = field_npc, dmg, state, object_id) do
    hp = max(0, field_npc.stats.health.current - dmg)
    stats = put_in(field_npc.stats, [:health, :current], hp)

    Context.Mobs.drop_hit_rewards(field_npc, state.map_id)

    {field_npc, state} =
      if hp == 0 do
        announce_death(%{field_npc | stats: stats}, state)
      else
        {%{field_npc | stats: stats}, state}
      end

    {:ok, field_npc, put_in(state, [:npcs, object_id], field_npc)}
  end

  # Death is announced with ControlNpc.dead/1; the client plays the death
  # animation on its own before the corpse is removed. The hp=0 sync must
  # reach the client BEFORE the dead control entry, otherwise it ignores
  # the state change.
  defp announce_death(field_npc, state) do
    corpse? = get_in(field_npc.npc.metadata, [:corpse, :hit_able]) || false

    field_npc =
      %{
        field_npc
        | dead?: true,
          send_control?: false,
          corpse?: corpse?,
          seq_counter: field_npc.seq_counter + 1,
          last_control_at: System.monotonic_time(:millisecond)
      }

    Context.Field.broadcast(state.topic, Packets.Stats.update_mob_stat(field_npc, :health))
    Context.Field.broadcast(state.topic, Packets.ControlNpc.dead(field_npc))

    # bodies stay for their dead window (corpse-hittable ones keep it in
    # full so players can keep striking them) before the field removes them
    fallback = if field_npc.corpse?, do: 20, else: 3
    corpse_time = get_in(field_npc.npc.metadata, [:dead, :time]) || fallback

    Process.send_after(self(), {:remove_npc, field_npc}, :timer.seconds(corpse_time))

    Context.Mobs.drop_rewards(field_npc, state.map_id)
    Context.Mobs.reward_exp(field_npc)

    # kill-count quest conditions (`npc`) credit every player who damaged the
    # mob; code param carries the npc id, target param the map id
    Enum.each(field_npc.damage_dealers, fn {_character_id, character} ->
      Managers.Quest.update_conditions(
        character.id,
        :npc,
        1,
        "",
        state.map_id,
        "",
        field_npc.npc.id
      )
    end)

    state = despawn(state, field_npc)

    {field_npc, open_mob_gates(state, field_npc)}
  end

  # A gate opens when the last mob of its spawn point dies: the blocking
  # meshes drop so the way through clears. The latch keeps it open even when
  # the spawn point's respawn cycle later refills the population, and the
  # hidden meshes are remembered so late joiners load them dropped.
  defp open_mob_gates(state, field_npc) do
    if Map.get(state, :script_controlled_npcs, false) do
      # the xblock script's own state handles the gate (meshes + guide event);
      # firing this legacy path too would repeat the guide event and reset the
      # client's guide stage
      state
    else
      open_mob_gates_legacy(state, field_npc)
    end
  end

  defp open_mob_gates_legacy(state, field_npc) do
    gates = Map.get(state, :mob_gates, %{})
    opened = Map.get(state, :opened_gates, MapSet.new())

    with %{spawn_point_id: spid, spawned_mobs: []} <-
           get_in(state, [:npc_spawns, field_npc.spawn_point_id]),
         false <- MapSet.member?(opened, spid),
         %{meshes: meshes} = gate <- Map.get(gates, spid) do
      Enum.each(meshes, &Context.Field.broadcast(state.topic, Packets.Trigger.hide_mesh(&1)))

      if guide_event = Map.get(gate, :guide_event) do
        Context.Field.broadcast(state.topic, Packets.Trigger.guide_event(guide_event))
      end

      state
      |> Map.put(:opened_gates, MapSet.put(opened, spid))
      |> Map.put(:hidden_meshes, Map.get(state, :hidden_meshes, []) ++ meshes)
    else
      _ -> state
    end
  end

  defp tick_npc(now, object_id, npc, {live, corpses}) do
    npc = advance_patrol(npc, now)

    cond do
      npc.dead? and npc.corpse? and now - npc.last_control_at >= @corpse_broadcast_ms ->
        npc =
          npc
          |> Map.update!(:seq_counter, &(&1 + 1))
          |> Map.put(:last_control_at, now)

        {[{object_id, npc}], {live, [npc | corpses]}}

      not npc.dead? and (npc.send_control? or now - npc.last_control_at >= @idle_control_ms) ->
        npc =
          npc
          |> Map.update!(:seq_counter, &(&1 + 1))
          |> Map.put(:last_control_at, now)
          |> Map.put(:send_control?, false)

        {[{object_id, npc}], {[npc | live], corpses}}

      true ->
        {[{object_id, npc}], {live, corpses}}
    end
  end

  # follow-dummies walk their waypoints linearly; position updates stream
  # to clients through the normal control broadcast, and the dummy despawns
  # at the end of the path
  defp advance_patrol(%{patrol: nil} = npc, _now), do: npc
  defp advance_patrol(%{patrol: %{waypoints: []}} = npc, _now), do: npc

  defp advance_patrol(npc, now) do
    patrol = npc.patrol
    dt = max(now - Map.get(patrol, :last_at, now), 1)
    waypoint = Enum.fetch!(patrol.waypoints, patrol.index)
    step = patrol.speed * dt / 1000.0

    {position, velocity, arrived?} = step_toward(npc.position, waypoint, step, patrol.speed, dt)
    patrol = Map.put(patrol, :last_at, now)

    cond do
      arrived? and patrol.index + 1 >= length(patrol.waypoints) ->
        # the scripted move ends here: the player regains control, so any
        # guide hint held during the move is released now
        send(self(), :release_guide_hold)
        Process.send_after(self(), {:remove_npc, npc}, 0)
        %{npc | patrol: nil}

      arrived? ->
        %{npc | patrol: Map.put(patrol, :index, patrol.index + 1), send_control?: true}

      true ->
        rotation = face_move_direction(npc.rotation, velocity)

        %{
          npc
          | position: position,
            velocity: velocity,
            rotation: rotation,
            send_control?: true,
            patrol: patrol
        }
    end
  end

  # actors face along their move direction: yaw from the horizontal
  # velocity, degrees — the ground-plane projection of the reference's
  # LookTo; the transform stores its front axis negated (M21 = -x, M22 =
  # -y), so yaw = atan2(dx, -dy). A zero velocity (waypoint arrival) keeps
  # the last heading
  defp face_move_direction(rotation, {vx, vy, _vz}) when vx != 0 or vy != 0 do
    yaw = :math.atan2(vx, -vy) * 180 / :math.pi()
    %{rotation | z: yaw}
  end

  defp face_move_direction(rotation, _velocity), do: rotation

  # full 3D step toward the waypoint (waypoints carry ground heights); the
  # velocity is what the control packet reports so the client interpolates
  # the movement instead of snapping
  defp step_toward(pos, target, step, speed, _dt) do
    dx = Map.get(target, :x) - pos.x
    dy = Map.get(target, :y) - pos.y
    dz = Map.get(target, :z) - pos.z
    dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist == 0 or dist <= step do
      {Map.put(pos, :z, Map.get(target, :z)), {0, 0, 0}, true}
    else
      vx = dx / dist * speed
      vy = dy / dist * speed
      vz = dz / dist * speed

      position = %{
        pos
        | x: pos.x + dx / dist * step,
          y: pos.y + dy / dist * step,
          z: pos.z + dz / dist * step
      }

      {position, {vx, vy, vz}, false}
    end
  end
end
