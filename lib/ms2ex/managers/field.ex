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
  @idle_control_ms 2000
  # one app-wide counter feeds players and mounts, while each field instance
  # owns a local counter for npcs, portals, spawn points and items
  @local_id_counter 50_000_000

  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    field_name = Context.Field.field_name(map_id, channel_id)

    {local_id_counter, portals} = Field.Portal.load(map_id, @local_id_counter)
    # {counter, interactable} = load_interactable(map, counter)

    state = %{
      channel_id: channel_id,
      local_id_counter: local_id_counter,
      interactable: %{},
      items: %{},
      map_id: map_id,
      mounts: %{},
      npcs: %{},
      npc_spawns: %{},
      portals: portals,
      sessions: %{},
      topic: field_name
    }

    send(self(), :load_npc_spawns)
    send(self(), :send_updates)
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

  def handle_call({:add_region_skill, skill_cast}, _from, state) do
    source_id = Ms2ex.generate_int()

    Context.Field.broadcast(
      state.topic,
      Packets.RegionSkill.add(source_id, skill_cast)
    )

    duration = SkillCast.duration(skill_cast)
    Process.send_after(self(), {:remove_region_skill, source_id}, duration + 5000)
    {:reply, :ok, state}
  end

  def handle_call({:add_buff, skill_cast, skill, character}, _from, state) do
    {:reply, :ok, Field.Buff.add_buff(skill_cast, skill, character, state)}
  end

  def handle_call({:lookup_npc, object_id}, _from, state) do
    case Map.get(state.npcs, object_id) do
      nil -> {:reply, :error, state}
      npc -> {:reply, {:ok, npc}, state}
    end
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}, object_id}, _from, state) do
    case Map.get(state.npcs, object_id) do
      nil ->
        {:reply, :error, state}

      %FieldNpc{} = field_npc ->
        field_npc = tag_attackers(field_npc, attacker)

        cond do
          # corpses replay a hit animation per strike; no further rewards
          field_npc.dead? && field_npc.corpse? ->
            field_npc = %{field_npc | seq_counter: field_npc.seq_counter + 1}
            Context.Field.broadcast(state.topic, Packets.ControlNpc.corpse_hit(field_npc))

            {:reply, {:ok, field_npc}, put_in(state, [:npcs, object_id], field_npc)}

          field_npc.dead? ->
            {:reply, {:ok, field_npc}, state}

          true ->
            apply_live_damage(field_npc, dmg, state, object_id)
        end
    end
  end

  defp tag_attackers(field_npc, attacker) do
    field_npc
    |> Map.put(:last_attacker, attacker)
    |> Map.put(:first_attacker, field_npc.first_attacker || attacker)
  end

  defp apply_live_damage(%FieldNpc{} = field_npc, dmg, state, object_id) do
    hp = max(0, field_npc.stats.health.current - dmg)
    stats = put_in(field_npc.stats, [:health, :current], hp)

    field_npc =
      if hp == 0 do
        announce_death(%{field_npc | stats: stats}, state.topic)
      else
        %{field_npc | stats: stats}
      end

    {:reply, {:ok, field_npc}, put_in(state, [:npcs, object_id], field_npc)}
  end

  # Death is announced with ControlNpc.dead/1; the client plays the death
  # animation on its own before the corpse is removed. The hp=0 sync must
  # reach the client BEFORE the dead control entry, otherwise it ignores
  # the state change.
  defp announce_death(field_npc, topic) do
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

    Context.Mobs.drop_rewards(field_npc)
    Context.Mobs.reward_exp(field_npc)

    # TODO
    # Player Condition update (quest, achievements...)

    field_npc
  end

  def handle_cast({:drop_item, source, item}, state) do
    {:noreply, Field.Item.drop_item(source, item, state)}
  end

  def handle_cast({:add_mob_drop, %FieldNpc{} = mob, %Schema.Item{} = item}, state) do
    {:noreply, Field.Item.add_mob_drop(mob, item, state)}
  end

  def handle_cast({:enter_battle_stance, character}, state) do
    Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, true))
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
      Enum.flat_map_reduce(state.npcs, {[], []}, fn {object_id, npc}, {live, corpses} ->
        cond do
          npc.dead? and npc.corpse? and now - npc.last_control_at >= @corpse_broadcast_ms ->
            npc =
              npc
              |> Map.update!(:seq_counter, &(&1 + 1))
              |> Map.put(:last_control_at, now)

            {[{object_id, npc}], {live, [npc | corpses]}}

          not npc.dead? and
              (npc.send_control? or now - npc.last_control_at >= @idle_control_ms) ->
            npc =
              npc
              |> Map.update!(:seq_counter, &(&1 + 1))
              |> Map.put(:last_control_at, now)
              |> Map.put(:send_control?, false)

            {[{object_id, npc}], {[npc | live], corpses}}

          true ->
            {[{object_id, npc}], {live, corpses}}
        end
      end)

    # one packet per npc
    for npc <- Enum.reverse(live_dirty) do
      Context.Field.broadcast(state.topic, Packets.ControlNpc.bytes([npc]))
    end

    for npc <- Enum.reverse(corpse_dirty) do
      Context.Field.broadcast(state.topic, Packets.ControlNpc.dead(npc))
    end

    {:noreply, %{state | npcs: Map.new(npcs)}}
  end

  def handle_info({:remove_region_skill, source_id}, state) do
    Context.Field.broadcast(state.topic, Packets.RegionSkill.remove(source_id))
    {:noreply, state}
  end

  def handle_info({:remove_status, status}, state) do
    Context.Field.broadcast(state.topic, Packets.Buff.send(:remove, status))
    {:noreply, state}
  end

  def handle_info({:leave_battle_stance, character}, state) do
    Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, false))
    {:noreply, state}
  end

  def handle_info(:send_updates, state) do
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- Managers.Character.lookup(char_id) do
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
end
