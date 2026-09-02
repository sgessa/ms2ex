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
    npc_spawn = Map.put(npc_spawn, :id, spawn_point_id)

    if mob_spawn?(npc_spawn) do
      # mob spawn points fill their population through the tick-driven spawn
      # cycle; the first cycle is due as soon as the spawn is loaded
      npc_spawn =
        npc_spawn
        |> Map.put(:spawned_mobs, [])
        |> Map.put(:spawn_tick, Ms2ex.sync_ticks())

      put_in(state, [:npc_spawns, spawn_point_id], npc_spawn)
    else
      state =
        if npc_spawn[:regen_check_time] > 0 || npc_spawn[:population] > 0 do
          put_in(state, [:npc_spawns, spawn_point_id], npc_spawn)
        else
          state
        end

      Enum.each(npc_ids, fn npc_id ->
        send(self(), {:add_npc, npc_id, npc_spawn})
      end)

      state
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

    # corpse-hittable bodies stay around for their full window so players can
    # keep striking them; everyone else despawns once the animation settles
    corpse_time =
      if field_npc.corpse? do
        get_in(field_npc.npc.metadata, [:dead, :time]) || 20
      else
        3
      end

    Process.send_after(self(), {:remove_npc, field_npc}, :timer.seconds(corpse_time))

    Context.Mobs.drop_rewards(field_npc, state.map_id)
    Context.Mobs.reward_exp(field_npc)

    state = despawn(state, field_npc)

    # TODO: Player Condition update (quest, achievements...)

    {field_npc, state}
  end

  defp tick_npc(now, object_id, npc, {live, corpses}) do
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
end
