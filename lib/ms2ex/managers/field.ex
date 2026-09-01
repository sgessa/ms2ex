defmodule Ms2ex.Managers.Field do
  use GenServer

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Types.Npc
  alias Ms2ex.Types.SkillCast

  alias Ms2ex.Managers.Field

  @splash_radius 800
  @splash_targets 8
  @updates_intval 1000

  # npcs are ticked on their own faster loop; only entities flagged as changed
  # are broadcast, bumping their sequence counter:
  #   if (send_control && !dead?) { seq_counter++; broadcast(); send_control? = false; }
  def next_local_id(state) do
    id = state.local_id_counter + 1
    {id, %{state | local_id_counter: id}}
  end

  @npc_tick_intval 15

  # animation transitions keep dirtying npcs on live servers, so even idle
  # ones re-announce themselves every few seconds; this also covers the
  # client dropping controls sent while it asynchronously loads the entity
  # every npc streams control entries continuously at this cadence,
  # matching what live servers emit and what the client expects
  @idle_control_ms 30
  # one app-wide counter feeds players and mounts, while each field instance
  # owns a local counter for npcs, portals, spawn points and items
  @local_id_counter 50_000_000

  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    field_name = Context.Field.field_name(map_id, channel_id)

    {local_id_counter, portals} = Field.Portal.load(map_id, @local_id_counter)
    # {counter, interactable} = load_interactable(map, counter)

    state = %{
      buffs: %{},
      channel_id: channel_id,
      local_id_counter: local_id_counter,
      interactable: %{},
      items: %{},
      map_id: map_id,
      mounts: %{},
      npcs: %{},
      npc_spawns: %{},
      players: %{},
      portals: portals,
      regions: %{},
      sessions: %{},
      tombstones: %{},
      topic: field_name
    }

    send(self(), :load_npc_spawns)
    send(self(), :tick_npcs)

    {:ok, state, {:continue, {:add_character, character}}}
  end

  # defp load_interactable(map, counter) do
  #   # TODO group these objects by their correct packet type
  #   Enum.reduce(map.interactable_objects, {counter, %{}}, fn object, {counter, objects} ->
  #     object = Map.put(object, :object_id, counter)
  #     {counter + 1, Map.put(objects, object.uuid, object)}
  #   end)
  # end

  def handle_continue({:add_character, character}, state) do
    {:noreply, Field.Character.add_character(character, state)}
  end

  def handle_call({:add_character, character}, _from, state) do
    {:reply, {:ok, self()}, Field.Character.add_character(character, state)}
  end

  def handle_call({:remove_character, character}, _from, state) do
    send(self(), :maybe_stop)
    {:reply, :ok, Field.Character.remove_character(character, state)}
  end

  def handle_call({:pickup_item, character, object_id}, _from, state) do
    case Map.get(state.items, object_id) do
      nil ->
        {:reply, :error, state}

      item ->
        {:reply, {:ok, item}, Field.Item.pickup_item(character, item, state)}
    end
  end

  # hitting a tombstone reduces its remaining hits; reaching zero revives the
  # owner
  def handle_call({:hit_tombstone, object_id, hits}, _from, state) do
    case Enum.find(state.tombstones, fn {_id, tombstone} -> tombstone.object_id == object_id end) do
      {owner_id, tombstone} ->
        remaining = max(tombstone.hits_remaining - hits, 0)
        tombstone = %{tombstone | hits_remaining: remaining}
        Context.Field.broadcast(state.topic, Packets.Tombstone.bytes(tombstone))

        state = put_in(state, [:tombstones, owner_id], tombstone)

        if remaining == 0 do
          Managers.Character.cast(owner_id, {:revive, :safe})
        end

        {:reply, :ok, state}

      nil ->
        {:reply, :error, state}
    end
  end

  def handle_call({:add_region_skill, skill_cast}, _from, state) do
    source_id = Ms2ex.generate_int()

    Context.Field.broadcast(
      state.topic,
      Packets.RegionSkill.add(source_id, skill_cast)
    )

    case SkillCast.splash_skill_cast(skill_cast) do
      {splash_cast, splash} ->
        interval = Map.get(splash, :interval, 0) || 0
        fires = max(Map.get(splash, :fire_count, 0) || 0, 1)

        end_tick =
          Ms2ex.sync_ticks() + (Map.get(splash, :remove_delay, 0) || 0) + (fires - 1) * interval

        state =
          if interval > 0 and fires > 1 do
            # repeating region: first hit now, then every interval until the
            # fire count runs out
            state = apply_splash_skill(splash_cast, state)

            region = %{
              splash_cast: splash_cast,
              interval: interval,
              fires_left: fires - 1,
              end_tick: end_tick
            }

            Process.send_after(self(), {:region_tick, source_id}, interval)
            put_in(state, [:regions, source_id], region)
          else
            apply_splash_skill(splash_cast, state)
          end

        Process.send_after(
          self(),
          {:remove_region_skill, source_id},
          max(end_tick - Ms2ex.sync_ticks(), 1)
        )

        {:reply, :ok, state}

      nil ->
        duration = SkillCast.duration(skill_cast)
        Process.send_after(self(), {:remove_region_skill, source_id}, duration + 5000)
        {:reply, :ok, state}
    end
  end

  def handle_call({:add_buff, skill_cast, skill, character}, _from, state) do
    {buff, state} = Field.Buff.add_buff(skill_cast, skill, character, state)
    reply = if is_nil(buff), do: :error, else: {:ok, buff}
    {:reply, reply, state}
  end

  def handle_call({:add_effect_buff, effect_id, effect_level, character}, _from, state) do
    {_buff, state} = Field.Buff.add_effect_buff(effect_id, effect_level, character, state)
    {:reply, :ok, state}
  end

  def handle_call({:lookup_npc, object_id}, _from, state) do
    case Map.get(state.npcs, object_id) do
      nil -> {:reply, :error, state}
      npc -> {:reply, {:ok, npc}, state}
    end
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}, object_id}, _from, state) do
    {reply, state} = damage_npc(state, attacker, dmg, object_id)
    {:reply, reply, state}
  end

  def handle_call({:apply_skill_effects, skill_cast, mob_id}, _from, state) do
    {:reply, :ok, apply_skill_effects(state, skill_cast, mob_id)}
  end

  # applies the attack's on-hit effects (skills + skills_on_damage) to a mob;
  # effects that carry a splash are region skills and are not applied as buffs
  def apply_skill_effects(state, skill_cast, mob_id) do
    case Map.get(state.npcs, mob_id) do
      %FieldNpc{dead?: false} = mob ->
        skill_cast
        |> SkillCast.attack_skills()
        |> Enum.reject(&Map.get(&1, :has_splash, false))
        |> Enum.reduce(state, fn effect, state ->
          {_buff, state} =
            Field.Buff.add_mob_buff(
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

  # applies damage to an npc directly; used by inflict_dmg and the buff tick loop
  def damage_npc(state, attacker, dmg, object_id) do
    case Map.get(state.npcs, object_id) do
      nil ->
        {:error, state}

      %FieldNpc{} = field_npc ->
        field_npc = tag_attackers(field_npc, attacker)

        cond do
          # corpses replay a hit animation and drop corpse loot per strike
          field_npc.dead? && field_npc.corpse? ->
            field_npc = %{field_npc | seq_counter: field_npc.seq_counter + 1}
            Context.Field.broadcast(state.topic, Packets.ControlNpc.corpse_hit(field_npc))

            Context.Mobs.drop_corpse_rewards(field_npc, attacker, state.map_id)

            {{:ok, field_npc}, put_in(state, [:npcs, object_id], field_npc)}

          field_npc.dead? ->
            {{:ok, field_npc}, state}

          true ->
            apply_live_damage(field_npc, dmg, state, object_id)
        end
    end
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

    field_npc =
      if hp == 0 do
        announce_death(%{field_npc | stats: stats}, state.topic, state.map_id)
      else
        %{field_npc | stats: stats}
      end

    {{:ok, field_npc}, put_in(state, [:npcs, object_id], field_npc)}
  end

  # Death is announced with ControlNpc.dead/1; the client plays the death
  # animation on its own before the corpse is removed. The hp=0 sync must
  # reach the client BEFORE the dead control entry, otherwise it ignores
  # the state change.
  defp announce_death(field_npc, topic, map_id) do
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

    Context.Field.broadcast(topic, Packets.Stats.update_mob_stat(field_npc, :health))
    Context.Field.broadcast(topic, Packets.ControlNpc.dead(field_npc))

    # corpse-hittable bodies stay around for their full window so players can
    # keep striking them; everyone else despawns once the animation settles
    corpse_window? = field_npc.corpse?

    corpse_time =
      if corpse_window? do
        get_in(field_npc.npc.metadata, [:dead, :time]) || 20
      else
        3
      end

    Process.send_after(self(), {:remove_npc, field_npc}, :timer.seconds(corpse_time))

    Context.Mobs.drop_rewards(field_npc, map_id)
    Context.Mobs.reward_exp(field_npc)

    # TODO
    # Player Condition update (quest, achievements...)

    field_npc
  end

  def handle_cast({:drop_item, source, item}, state) do
    {:noreply, Field.Item.drop_item(source, item, state)}
  end

  def handle_cast({:add_mob_drop, %FieldNpc{} = mob, %Schema.Item{} = item, receiver}, state) do
    {:noreply, Field.Item.add_mob_drop(mob, item, receiver, state)}
  end

  # a dead player's tombstone is broadcast so other players can hit it; the
  # owner is keyed by character id for the revive lookup
  def handle_cast({:add_tombstone, character}, state) do
    tombstone =
      Ms2ex.Types.Tombstone.new(character, Map.get(character, :death_count, 0) || 0)

    Context.Field.broadcast(state.topic, Packets.Tombstone.bytes(tombstone))

    {:noreply, put_in(state, [:tombstones, character.id], tombstone)}
  end

  def handle_cast({:remove_tombstone, character_id}, state) do
    {:noreply, update_in(state, [:tombstones], &Map.delete(&1, character_id))}
  end

  # buffs die with their owner; remove every buff owned by the object id
  def handle_cast({:remove_owner_buffs, owner_object_id}, state) do
    state =
      state.buffs
      |> Enum.filter(fn {{owner_id, _effect, _caster}, _buff_id} ->
        owner_id == owner_object_id
      end)
      |> Enum.reduce(state, fn {{_owner, _effect, _caster}, buff_id}, state ->
        Field.Buff.remove_buff(buff_id, state)
      end)

    {:noreply, state}
  end

  def handle_cast({:enter_battle_stance, character}, state) do
    # battle-start packets are emitted by the cast handler in order; the
    # field process only schedules the eventual stance drop
    Process.send_after(self(), {:leave_battle_stance, character}, 5_000)
    {:noreply, state}
  end

  #
  # NPCs
  #

  def handle_info(:load_npc_spawns, state) do
    Field.Npc.load_npc_spawns(state)
    Field.Npc.load_mob_spawns(state)
    {:noreply, state}
  end

  def handle_info({:add_npc_spawn, npc_spawn, npc_ids}, state) do
    {:noreply, Field.Npc.load_spawn(state, npc_spawn, npc_ids)}
  end

  def handle_info({:add_npc, npc_id, npc_spawn}, state) do
    {:noreply, Field.Npc.load_npc(state, npc_id, npc_spawn)}
  end

  def handle_info({:add_mob, %Npc{} = npc, position}, state) do
    {:noreply, Field.Npc.load_npc(state, npc, %{position: position, rotation: nil})}
  end

  def handle_info({:remove_npc, field_npc}, state) do
    Context.Field.broadcast(field_npc.field, Packets.FieldRemoveNpc.bytes(field_npc.object_id))
    Context.Field.broadcast(field_npc.field, Packets.ProxyGameObj.remove_npc(field_npc))

    {:noreply, Field.Npc.remove_npc(field_npc, state)}
  end

  # corpse npcs keep re-announcing their death entry once per second while
  # their body remains interactable
  @corpse_broadcast_ms 1000

  def handle_info(:tick_npcs, state) do
    Process.send_after(self(), :tick_npcs, @npc_tick_intval)

    now = System.monotonic_time(:millisecond)

    {npcs, {live_dirty, corpse_dirty}} =
      Enum.flat_map_reduce(state.npcs, {[], []}, fn {object_id, npc}, acc ->
        tick_npc(now, object_id, npc, acc)
      end)

    # one packet per npc
    boss_target = state.players |> Map.values() |> List.first()

    for npc <- Enum.reverse(live_dirty) do
      Context.Field.broadcast(state.topic, Packets.ControlNpc.bytes([npc], boss_target))
    end

    for npc <- Enum.reverse(corpse_dirty) do
      Context.Field.broadcast(state.topic, Packets.ControlNpc.dead(npc))
    end

    {:noreply, %{state | npcs: Map.new(npcs)}}
  end

  def handle_info({:region_tick, source_id}, state) do
    case Map.get(state.regions, source_id) do
      nil ->
        {:noreply, state}

      region ->
        if region.fires_left <= 0 or Ms2ex.sync_ticks() >= region.end_tick do
          {:noreply, %{state | regions: Map.delete(state.regions, source_id)}}
        else
          {:noreply, region_tick(region, source_id, state)}
        end
    end
  end

  def handle_info({:remove_region_skill, source_id}, state) do
    Context.Field.broadcast(state.topic, Packets.RegionSkill.remove(source_id))
    {:noreply, state}
  end

  def handle_info({:remove_status, status}, state) do
    Context.Field.broadcast(state.topic, Packets.Buff.send(:remove, status))
    {:noreply, state}
  end

  def handle_info({:buff_tick, buff_id}, state) do
    state = Field.Buff.tick(buff_id, state)
    {:noreply, state}
  end

  def handle_info({:remove_buff, buff_id}, state) do
    state = Field.Buff.remove_buff(buff_id, state)
    {:noreply, state}
  end

  def handle_info({:leave_battle_stance, character}, state) do
    Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, false))
    Context.Field.broadcast(character, Packets.ProxyGameObj.update_state(character, 1))
    {:noreply, state}
  end

  def handle_info(:send_updates, state) do
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- Managers.Character.call(char_id, :lookup),
           # dead players freeze in place; a position-only update would clear
           # their dead/collision state on clients, so skip them here
           false <- Map.get(char, :dead?, false) do
        Context.Field.broadcast(state.topic, Packets.ProxyGameObj.update_player(char))
      end
    end

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
  end

  def handle_info(:maybe_stop, state) do
    if Enum.empty?(state.sessions) do
      Logger.info("Field #{state.map_id} @ Channel #{state.channel_id} is empty. Stopping.")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(data, state) do
    Logger.warning("[Field] Unknown message: #{inspect(data)}")
    {:noreply, state}
  end

  # decides whether a corpse keeps re-announcing its death entry and whether a
  # live npc gets a control update this tick
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

  # a region/splash attack fires its splash skill once over the mobs near the
  # cast position (e.g. Ice Spear's splash skill 10300052 applies the chill)
  def apply_splash_skill(splash_cast, state) do
    targets =
      state.npcs
      |> Enum.filter(fn {_id, npc} ->
        not npc.dead? and in_splash_range?(npc, splash_cast)
      end)
      |> Enum.take(@splash_targets)

    hit_mobs(splash_cast, targets, state)
  end

  defp region_tick(region, source_id, state) do
    state = apply_splash_skill(region.splash_cast, state)
    state = update_in(state, [:regions, source_id], &%{&1 | fires_left: &1.fires_left - 1})
    Process.send_after(self(), {:region_tick, source_id}, region.interval)
    state
  end

  defp hit_mobs(splash_cast, targets, state) do
    {mobs, state} =
      Enum.reduce(targets, {[], state}, fn {object_id, mob}, {mobs, state} ->
        dmg = Context.Damage.calculate(splash_cast, mob, false)
        {_reply, state} = damage_npc(state, splash_cast.caster, dmg.dmg, object_id)
        state = apply_skill_effects(state, splash_cast, object_id)
        {[{mob, dmg} | mobs], state}
      end)

    if mobs != [] do
      Context.Field.broadcast(
        state.topic,
        Packets.SkillDamage.damage(splash_cast, Enum.reverse(mobs))
      )
    end

    state
  end

  defp in_splash_range?(npc, splash_cast) do
    case {npc.position, splash_cast.position} do
      {%{x: x1, y: y1}, %{x: x2, y: y2}} ->
        (x1 - x2) ** 2 + (y1 - y2) ** 2 <= @splash_radius ** 2

      _ ->
        false
    end
  end
end
