defmodule Ms2ex.Managers.Field.Npc do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Navigation
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  alias Ms2ex.Managers.Field.Npc.Battle
  alias Ms2ex.Managers.Field.Npc.Patrol

  # a slow keepalive re-announcing each npc (counter refresh, position
  # re-anchor): the client interpolates walking from the control's
  # position + velocity, and state changes (movement legs, aggro, hits,
  # animation transitions) broadcast immediately through the send_control
  # flag. A fast keepalive floods the client — every field npc re-sent
  # every few tens of ms is thousands of packets per second once a map
  # has a few dozen mobs, and the client queues everything else (damage,
  # stat records) behind the flood
  @idle_control_ms 500
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
    # npc_spawns is keyed by the map's spawn point id — the same id trigger
    # scripts use to spawn/destroy/emote the staged npcs
    spawn_point_id = npc_spawn.spawn_point_id

    npc_spawn =
      npc_spawn
      |> Map.put(:spawned_mobs, [])
      |> Map.put(:spawned_npcs, [])

    state = put_in(state, [:npc_spawns, spawn_point_id], npc_spawn)

    cond do
      # event spawn points are script summons: they appear only through a
      # spawn_monster action, whatever their on-create flag says. Every other
      # spawn loads with the field per its on-create flag, scripted map or not
      npc_spawn[:is_event] == true ->
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
          {:ok, state} = spawn_and_track(state, npc_id, npc_spawn)
          state
        end)

      true ->
        # story npcs that wait for a spawn_monster script action
        state
    end
  end

  defp spawn_and_track(state, npc_id, npc_spawn) do
    case spawn_npc(state, npc_id, npc_spawn) do
      {%Types.FieldNpc{} = field_npc, state} ->
        state =
          update_in(
            state,
            [:npc_spawns, npc_spawn.spawn_point_id, :spawned_npcs],
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
        spawn_point_id: npc_spawn[:spawn_point_id],
        npc: npc,
        map_id: state.map_id,
        position: npc_spawn[:position],
        rotation: npc_spawn[:rotation],
        spawn_radius: npc_spawn[:spawn_radius],
        field: state.topic
      })

    Managers.Field.broadcast(state.topic, Packets.FieldAddNpc.add_npc(field_npc))
    Managers.Field.broadcast(state.topic, Packets.ProxyGameObj.load_npc(field_npc))

    {field_npc, put_in(state, [:npcs, object_id], field_npc)}
  end

  # A mob death frees its population slot and schedules the next spawn cycle:
  # a spawn wiped down to zero mobs starts its cooldown, while a partial kill
  # (with no cycle pending) respawns at twice the cooldown. A zero cooldown
  # means the spawn point never refills. Event spawn points (script
  # summons) never refill — the script decides when they appear again.
  def despawn(state, %Types.FieldNpc{} = field_npc) do
    case get_in(state, [:npc_spawns, field_npc.spawn_point_id]) do
      %{} = spawn when is_map_key(spawn, :npc_ids) ->
        spawned = List.delete(spawn.spawned_mobs, field_npc.object_id)
        spawn = %{spawn | spawned_mobs: spawned}
        put_in(state, [:npc_spawns, spawn.spawn_point_id], schedule_spawn(spawn))

      _ ->
        state
    end
  end

  defp schedule_spawn(%{is_event: true} = spawn), do: spawn

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

      %Types.FieldNpc{} = field_npc ->
        field_npc = tag_attackers(field_npc, attacker)
        field_npc = Battle.aggro(field_npc, attacker, Ms2ex.sync_ticks())

        cond do
          field_npc.dead? && field_npc.corpse? ->
            field_npc = %{field_npc | seq_counter: field_npc.seq_counter + 1}
            Managers.Field.broadcast(state.topic, Packets.ControlNpc.corpse_hit(field_npc))
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
      %Types.FieldNpc{dead?: false} = mob ->
        skill_cast
        |> Types.SkillCast.attack_skills()
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
    now = Ms2ex.sync_ticks()
    state = advance_projectiles(state, now)

    {npcs, {live_dirty, corpse_dirty, hits}} =
      Enum.flat_map_reduce(state.npcs, {[], [], []}, fn {object_id, npc},
                                                        {live, corpses, all_hits} ->
        npc = advance_patrol(npc, now)
        {npc, npc_hits} = Battle.tick(npc, state, now)
        {entry, {live, corpses}} = tick_npc(now, object_id, npc, {live, corpses})
        {entry, {live, corpses, all_hits ++ npc_hits}}
      end)

    boss_target = state.players |> Map.values() |> List.first()
    live = Enum.reverse(live_dirty)

    # mob skill hits land here: the attack record (projectile launch)
    # goes out at the release keyframe. Overlap shots home to their victim
    # (the client chases the projectile) and their damage applies when the
    # flight timer elapses; straight shots are fire-and-forget — the field
    # simulates the flight and only lands a hit when the projectile's
    # flight actually reaches the victim, so sidestepping or outrunning
    # one dodges it. Melee swings and ground indicators stay instant.
    state =
      Enum.reduce(hits, state, fn hit, state ->
        key = {hit.caster_object_id, hit.attack_counter}

        cond do
          hit.travel_ms > 0 and hit.look_at_type == 1 ->
            state = broadcast_launch(state, hit, hit.target_object_id)
            Process.send_after(self(), {:npc_projectile_impact, hit}, hit.travel_ms)
            state

          hit.travel_ms > 0 ->
            state = broadcast_launch(state, hit, 0)

            projectile = %{
              hit: hit,
              origin: hit.position,
              direction: hit.direction,
              velocity: hit.velocity,
              max_distance: hit.flight,
              traveled: 0.0,
              victim_id: hit.character_id,
              launched_at: now
            }

            projectiles = Map.put(Map.get(state, :projectiles, %{}), key, projectile)
            Map.put(state, :projectiles, projectiles)

          true ->
            apply_hit(state, hit)
            state
        end
      end)

    # mobs that arrived home this tick healed: announce the new health
    # before their idle control lands
    for npc <- live, npc.stat_dirty? do
      Managers.Field.broadcast(state.topic, Packets.Stats.update_mob_stat(npc, :health))
    end

    # periodic controls stay single-npc entries: the reference's control
    # loop sends one npc per packet, and the client demonstrably mishandles
    # multi-entry batches here (frozen mobs, lost HP-bar transitions)
    for npc <- live do
      Managers.Field.broadcast(state.topic, Packets.ControlNpc.bytes([npc], boss_target))
    end

    npcs =
      live
      |> Enum.reduce(Map.new(npcs), fn npc, npcs ->
        Map.put(npcs, npc.object_id, %{npc | stat_dirty?: false})
      end)

    for npc <- Enum.reverse(corpse_dirty) do
      Managers.Field.broadcast(state.topic, Packets.ControlNpc.dead(npc))
    end

    %{state | npcs: npcs}
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
      case spawn_and_track(state, npc_id, spawn) do
        {:ok, state} -> {Map.get(state.npc_spawns, spawn.spawn_point_id), state}
        {:error, state} -> {spawn, state}
      end
    end)
  end

  @follow_dummies %{male: 2_040_998, female: 2_040_999}
  @follow_speed 150

  # spawns the invisible follow-dummy that walks a patrol path while the
  # player's client walks the player behind it (scripted carry sequences).
  # the dummy plays the waypoints' approach animations so the client keeps
  # end of a scripted carry: the player takes the route's last authored
  # waypoint, turned toward the npc standing nearest it. The cutscene camera
  # transition back to gameplay lands on that facing — without it the player
  # keeps whatever the client-side follow left them facing and the camera
  # swings to a stale angle. With no npc within talkable distance the player
  # is left alone (the follow already walked them to the endpoint)
  def finish_carry(state, %Types.FieldNpc{} = dummy) do
    character_id = dummy.follow_character_id

    with character_id when is_integer(character_id) <- character_id,
         true <- Map.has_key?(state.players, character_id),
         {:ok, character} <- Managers.Character.call(character_id, :lookup) do
      last_position = List.last(dummy.patrol.waypoints)[:position]
      # the player lands facing the carry's final leg — the direction the
      # client-side follow left them walking — not toward a guessed npc
      rotation = final_leg_facing(dummy.patrol.waypoints)

      if rotation && Navigation.valid_position?(state.map_id, last_position) do
        character = %{character | position: last_position, rotation: rotation}
        Managers.Character.call(character, {:update, character})

        state = Managers.Field.Trigger.track_position(state, character_id, last_position)

        Net.SenderSession.push(
          character,
          Packets.UserMoveByPortal.bytes(character, last_position, rotation)
        )

        state
      else
        state
      end
    else
      _ -> state
    end
  end

  # the facing a scripted carry leaves its passenger with: the direction
  # of the route's last leg. Single-waypoint routes have no leg to face
  # along — the follow already left the player facing somewhere sane
  defp final_leg_facing(waypoints) when length(waypoints) >= 2 do
    face_toward(Enum.at(waypoints, -2)[:position], List.last(waypoints)[:position])
  end

  defp final_leg_facing(_waypoints), do: nil

  # actors face along their front axis: yaw = atan2(dx, -dy) degrees, the
  # same convention the npc control packets encode
  defp face_toward(from, to) do
    yaw = :math.atan2(to.x - from.x, -(to.y - from.y)) * 180 / :math.pi()
    %{x: 0.0, y: 0.0, z: yaw}
  end

  # the following player in a grounded walking state
  def spawn_follow_dummy(state, character, way_points) do
    npc_id = Map.fetch!(@follow_dummies, character.gender)

    case spawn_npc(state, npc_id, %{position: character.position, rotation: nil, id: nil}) do
      {%Types.FieldNpc{} = field_npc, state} ->
        # spawn_npc may randomize mob positions; the dummy must start
        # exactly on the player it carries. The carry proceeds even when
        # the model cannot animate — the walk itself is client-side
        animations = Patrol.leg_animations(field_npc, way_points)

        base = %{
          waypoints: way_points,
          animations: animations,
          speeds: Patrol.leg_speeds(field_npc, way_points),
          index: 0,
          speed: @follow_speed,
          last_at: Ms2ex.sync_ticks(),
          despawn_on_finish?: true
        }

        # the first leg starts through the patrol machinery so every leg of
        # the carry resolves the same way: over the navmesh when possible,
        # on the authored straight line when the mesh has no route (the
        # carry must complete — the dummy never skips waypoints)
        field_npc = %{
          field_npc
          | position: character.position,
            patrol: base,
            follow_character_id: character.id
        }

        field_npc = Patrol.start_leg(field_npc, Ms2ex.sync_ticks())

        {field_npc, put_in(state, [:npcs, field_npc.object_id], field_npc)}

      {nil, state} ->
        {nil, state}
    end
  end

  defp spawn_missing_mobs(spawn, state) do
    missing = spawn.population - length(spawn.spawned_mobs)

    Enum.reduce(1..max(missing, 0), {spawn, state}, fn _i, {spawn, state} ->
      case spawn_npc(state, Enum.random(spawn.npc_ids), spawn) do
        {%Types.FieldNpc{} = field_npc, state} ->
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

  defp apply_live_damage(%Types.FieldNpc{} = field_npc, dmg, state, object_id) do
    hp = max(0, field_npc.stats.health.current - dmg)
    stats = put_in(field_npc.stats, [:health, :current], hp)

    Context.Mobs.drop_hit_rewards(field_npc, state.map_id)

    # the client's HP-bar update rides this stat record — the damage
    # records only render numbers; on death it must land before the dead
    # control entry or the client ignores the state change
    Managers.Field.broadcast(
      state.topic,
      Packets.Stats.update_mob_stat(%{field_npc | stats: stats}, :health)
    )

    {field_npc, state} =
      if hp == 0 do
        announce_death(%{field_npc | stats: stats}, state)
      else
        {%{field_npc | stats: stats}, state}
      end

    {:ok, field_npc, put_in(state, [:npcs, object_id], field_npc)}
  end

  # Death is announced with ControlNpc.dead/1; the client plays the death
  # animation on its own before the corpse is removed. The hp=0 stat record
  # has already landed (apply_live_damage broadcasts it before calling in),
  # otherwise the client ignores the dead control entry.
  defp announce_death(field_npc, state) do
    corpse? = get_in(field_npc.npc.metadata, [:corpse, :hit_able]) || false

    field_npc =
      %{
        field_npc
        | dead?: true,
          send_control?: false,
          corpse?: corpse?,
          seq_counter: field_npc.seq_counter + 1,
          last_control_at: Ms2ex.sync_ticks()
      }

    Managers.Field.broadcast(state.topic, Packets.ControlNpc.dead(field_npc))

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
      Enum.each(meshes, &Managers.Field.broadcast(state.topic, Packets.Trigger.hide_mesh(&1)))

      if guide_event = Map.get(gate, :guide_event) do
        Managers.Field.broadcast(state.topic, Packets.Trigger.guide_event(guide_event))
      end

      state
      |> Map.put(:opened_gates, MapSet.put(opened, spid))
      |> Map.put(:hidden_meshes, Map.get(state, :hidden_meshes, []) ++ meshes)
    else
      _ -> state
    end
  end

  @doc """
  Expires a finished scripted emotion: once the emote's playback window
  elapses the npc falls back to its idle sequence and flags itself dirty
  so the next control broadcast carries the revert.
  """
  @spec expire_emote(Types.FieldNpc.t(), integer()) :: Types.FieldNpc.t()
  def expire_emote(%Types.FieldNpc{} = npc, now) do
    case npc.emote do
      %{revert_at: revert_at} when now >= revert_at ->
        %{npc | animation: npc.emote.idle_sequence_id, emote: nil, send_control?: true}

      _ ->
        npc
    end
  end

  def expire_emote(npc, _now), do: npc

  # the damage application shared by the instant path and the projectile
  # impact: the character manager resolves the damage against its own
  # defenses (funneling death and the stat broadcast through the normal
  # paths) and the field broadcasts the hit so every client sees the numbers
  defp apply_hit(state, hit, landed_at \\ nil) do
    case Managers.Character.call(hit.character_id, {:mob_hit, hit}) do
      {:ok, applied} ->
        # the record's position anchors the client's impact visuals (a
        # projectile's explosion renders at the landing point, not the
        # shooter)
        record =
          hit
          |> Map.merge(applied)
          |> stamp_position(landed_at)

        Managers.Field.broadcast(state.topic, Packets.SkillDamage.mob_hit(record))

        schedule_hit_skills(state, hit, landed_at)

      :error ->
        :ok
    end
  end

  defp stamp_position(record, %Types.Coord{} = landed_at),
    do: %{record | position: landed_at}

  defp stamp_position(record, _), do: record

  # a landed swing fires its on-hit effect skills where it landed: each
  # detonates after its splash delay (a thrown bomb's explosion cube goes
  # off a beat after impact). The landing point defaults to the victim's
  # live position — splash effects center on their targets
  #
  # TODO: only splash effect skills fire; on-hit entries without a splash
  # (stuns, slows, knockbacks riding the attack's effect list) are
  # dropped, as are effects keyed to the damage landing
  defp schedule_hit_skills(state, hit, landed_at) do
    skills = Map.get(hit, :hit_skills, [])

    if skills != [] do
      center =
        landed_at || get_in(state, [:player_positions, hit.character_id, :position]) ||
          hit.position

      Enum.each(skills, fn entry ->
        payload = %{hit: hit, center: center, skill_id: entry.skill_id, level: entry.level}

        Process.send_after(self(), {:npc_skill_explosion, payload}, max(entry.delay_ms, 0))
      end)
    end
  end

  # resolves an on-hit effect skill's detonation: every player standing in
  # the skill's attack cube around the landing point takes its hit
  def apply_skill_explosion(%{hit: hit, center: center, skill_id: skill_id, level: level}, state) do
    with %{} = level_doc <- Storage.Skills.get_meta(skill_id)[:levels][to_string(level)],
         attack when is_map(attack) <- first_attack(level_doc),
         rate when is_number(rate) and rate > 0 <- get_in(attack, [:damage, :rate]) do
      radius = get_in(attack, [:range, :distance]) || 0
      height = get_in(attack, [:range, :height]) || 0

      victims =
        for {character_id, object_id} <- state.players,
            position = get_in(state, [:player_positions, character_id, :position]),
            match?(%Types.Coord{}, position),
            horizontal_distance_sq(center, position) <= radius * radius,
            abs(position.z - center.z) <= height do
          Map.merge(hit, %{
            character_id: character_id,
            target_object_id: object_id,
            skill_id: skill_id,
            skill_level: level,
            rate: rate,
            position: center,
            hit_skills: [],
            server_tick: Ms2ex.sync_ticks()
          })
        end

      Enum.each(victims, &apply_hit(state, &1))
    end

    state
  end

  defp first_attack(level_doc) do
    level_doc
    |> Map.get(:motions, [])
    |> List.wrap()
    |> Enum.flat_map(&List.wrap(Map.get(&1, :attacks)))
    |> Enum.find(&is_map(&1))
  end

  defp horizontal_distance_sq(%Types.Coord{} = a, %Types.Coord{} = b) do
    dx = a.x - b.x
    dy = a.y - b.y
    dx * dx + dy * dy
  end

  # a mob's landed swing reaches clients as the attack record first (the
  # client's projectile visuals: one packet per magic-path segment) and
  # the damage numbers when the projectile lands
  # the record's target id is the client's aim source: lookAtType 1 paths
  # fly the projectile at (and chasing) that actor, so aimed shots carry
  # the victim; fixed-line paths (lookAtType 0/2) carry zero and fly their
  # own line, dodgeable by stepping off it
  defp broadcast_launch(state, hit, target_id) do
    with id when is_integer(id) and id > 0 <- hit[:magic_path_id],
         segments when is_list(segments) <- Storage.Table.MagicPaths.get(id) || [] do
      segments
      |> Enum.with_index()
      |> Enum.each(fn {_segment, index} ->
        launch = Map.merge(hit, %{direction: launch_direction(hit.direction)})

        Managers.Field.broadcast(
          state.topic,
          Packets.SkillDamage.target(launch, index, target_id)
        )
      end)
    end

    state
  end

  # the shot direction a launch record carries: the world unit vector from
  # the shooter toward the victim at release. Fixed-line paths (lookAtType
  # 0/2) fly their line from it; aimed paths (lookAtType 1) key off the
  # record's target id instead
  def launch_direction(world_direction), do: world_direction

  @doc """
  Applies an aimed (lookAtType 1) projectile's damage when its flight
  time elapses: the client chases the shot onto its victim, so the damage
  follows the timer. The shot lands while its victim is still on the
  field, live-synced, and inside the firing attack's reach of the launch
  point. (Fixed-line shots are simulated per tick instead — see
  advance_projectiles/2.)
  """
  def apply_projectile_impact(state, hit) do
    reach = hit.range + 60
    launch = hit.position
    victim_position = get_in(state, [:player_positions, hit.character_id, :position])

    lands? =
      Map.has_key?(state.players, hit.character_id) and
        match?(%Types.Coord{}, victim_position) and
        distance_sq(launch, victim_position) <= reach * reach

    if lands? do
      apply_hit(state, hit, victim_position)
    end

    state
  end

  @projectile_radius 150
  @max_flight_step_ms 200

  # straight-shot projectiles fly their fixed line: each tick advances the
  # shot along its launch direction and lands it only when the flight
  # reaches the victim's live position — sidestepping or outrunning one
  # dodges it. Shots that cover their max distance without colliding
  # despawn harmlessly
  def advance_projectiles(state, now) do
    projectiles = Map.get(state, :projectiles, %{})

    {kept, impacts} =
      Enum.flat_map_reduce(projectiles, [], fn {key, p}, impacts ->
        dt = (now - p.launched_at) |> max(0) |> min(@max_flight_step_ms)
        p = %{p | traveled: p.traveled + p.velocity * dt / 1000, launched_at: now}

        position = projectile_position(p)
        victim_position = get_in(state, [:player_positions, p.victim_id, :position])

        cond do
          not Map.has_key?(state.players, p.victim_id) ->
            # the victim left the field mid-flight: despawn without landing
            {[], impacts}

          match?(%Types.Coord{}, victim_position) and
              distance_sq(position, victim_position) <= @projectile_radius * @projectile_radius ->
            # collision: the hit applies and the projectile despawns
            {[], [{p.hit, position} | impacts]}

          p.traveled >= p.max_distance ->
            # the flight ran out: no direct hit, but an explosive round
            # still detonates where it lands
            {[], [{p.hit, position, :no_direct_hit} | impacts]}

          true ->
            {[{key, p}], impacts}
        end
      end)

    state = Map.put(state, :projectiles, Map.new(kept))

    Enum.each(impacts, fn
      {hit, position} ->
        apply_hit(state, hit, position)

      {hit, position, :no_direct_hit} ->
        schedule_hit_skills(state, hit, position)
    end)

    state
  end

  defp projectile_position(%{origin: origin, direction: direction, traveled: traveled}) do
    %Types.Coord{
      x: origin.x + direction.x * traveled,
      y: origin.y + direction.y * traveled,
      z: origin.z + direction.z * traveled
    }
  end

  defp distance_sq(%Types.Coord{} = a, %Types.Coord{} = b) do
    dx = a.x - b.x
    dy = a.y - b.y
    dz = a.z - b.z
    dx * dx + dy * dy + dz * dz
  end

  # a swing occupies the mob from its cast start until the playback's
  # end: controls stay silent through it
  defp swinging?(%{battle: %{cast: %{} = cast}}, now), do: now < cast.end_at
  defp swinging?(%{battle: %{swing_until: until}}, now) when is_integer(until), do: now < until
  defp swinging?(_npc, _now), do: false

  # a stunned mob holds position: its patrol leg freezes with the battle
  defp advance_patrol(%{stunned_until: until} = npc, now) when now < until, do: npc
  defp advance_patrol(npc, now), do: Patrol.advance_patrol(npc, now)


  defp tick_npc(now, object_id, npc, {live, corpses}) do
    npc = expire_emote(npc, now)

    {npc, broadcast} = control_plan(npc, now)

    case broadcast do
      :skip ->
        {[{object_id, npc}], {live, corpses}}

      :broadcast ->
        {[{object_id, npc}], {[npc | live], corpses}}

      :corpse ->
        {[{object_id, npc}], {live, [npc | corpses]}}
    end
  end

  # decides what this npc's control broadcast does this tick: a corpse
  # re-announces on its slow cadence, a state change (the cast start's
  # control pins the swing's sequence AND zeroes the mob's velocity)
  # always goes out, a mid-swing periodic anchor stays silent (any
  # further broadcast restarts the swing's sequence), and everything
  # else re-anchors on the idle cadence
  defp control_plan(%{dead?: true, corpse?: true} = npc, now)
       when now - npc.last_control_at >= @corpse_broadcast_ms do
    npc =
      npc
      |> Map.update!(:seq_counter, &(&1 + 1))
      |> Map.put(:last_control_at, now)

    {npc, :corpse}
  end

  defp control_plan(%{dead?: true} = npc, _now), do: {npc, :skip}

  defp control_plan(%{send_control?: true} = npc, now),
    do: {broadcast_control(npc, now), :broadcast}

  defp control_plan(%{dead?: false} = npc, now) do
    cond do
      swinging?(npc, now) -> {npc, :skip}
      now - npc.last_control_at >= @idle_control_ms -> {broadcast_control(npc, now), :broadcast}
      true -> {npc, :skip}
    end
  end

  # every broadcast bumps the sequence counter: the client re-applies a
  # control's sequence when its counter changes, and that re-apply is what
  # recovers a model after a client-side interruption — a hit flinch
  # displaces the current sequence instance, and a stream of unchanged
  # (sequence, counter) pairs would leave the model statuesqued in its
  # flinch-end pose. Looping walk/idle sequences hide the re-apply, and
  # one-shot swings are protected by the mid-swing control silence
  defp broadcast_control(npc, now) do
    npc
    |> Map.update!(:seq_counter, &(&1 + 1))
    |> Map.put(:last_control_at, now)
    |> Map.put(:send_control?, false)
  end
end
