defmodule Ms2ex.Managers.Field do
  use GenServer

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Types.SkillCast

  alias Ms2ex.Managers.Field

  @updates_intval 1000

  # npcs are ticked on their own faster loop; only entities flagged as changed
  # are broadcast, bumping their sequence counter:
  #   if (send_control && !dead?) { seq_counter++; broadcast(); send_control? = false; }
  @npc_tick_intval 15

  # animation transitions keep dirtying npcs on the reference server, so even
  # idle ones re-announce themselves every few seconds; this also covers the
  # client dropping controls sent while it asynchronously loads the entity
  @idle_control_ms 2000

  # players draw from the global id space; npcs, portals and items share the
  # local one, mirroring the reference server's per-field id counter
  @object_counter 10_000_000
  @local_object_counter 50_000_000
  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    field_name = Context.Field.field_name(map_id, channel_id)

    {local_counter, portals} = Field.Portal.load(map_id, @local_object_counter)
    # {counter, interactable} = load_interactable(map, counter)

    state = %{
      channel_id: channel_id,
      counter: @object_counter,
      local_counter: local_counter,
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
        field_npc = Map.put(field_npc, :last_attacker, attacker)
        hp = max(0, field_npc.stats.health.current - dmg)
        stats = put_in(field_npc.stats, [:health, :current], hp)
        field_npc = %{field_npc | stats: stats}

        if hp == 0 do
          # Death is announced with ControlNpc.dead/1; the client plays the
          # death animation on its own before the corpse is removed.
          # The hp=0 sync must reach the client BEFORE the dead control entry,
          # otherwise it ignores the state change.
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

          Logger.debug("NPC #{field_npc.npc.id} died (obj #{field_npc.object_id})")
          Context.Field.broadcast(state.topic, Packets.Stats.update_mob_stat(field_npc, :health))
          Context.Field.broadcast(state.topic, Packets.ControlNpc.dead(field_npc))

          corpse_time = get_in(field_npc.npc.metadata, [:dead, :time]) || 3
          Process.send_after(self(), {:remove_npc, field_npc}, :timer.seconds(corpse_time))

          Context.Mobs.drop_rewards(field_npc)
          Context.Mobs.reward_exp(field_npc)

          # TODO
          # Player Condition update (quest, achievements...)
        end

        {:reply, {:ok, field_npc}, put_in(state, [:npcs, object_id], field_npc)}
    end
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

    unless live_dirty == [] do
      # one packet per npc, mirroring the reference broadcast sites
      Enum.each(Enum.reverse(live_dirty), fn npc ->
        Context.Field.broadcast(state.topic, Packets.ControlNpc.bytes([npc]))
      end)
    end

    unless corpse_dirty == [] do
      Enum.each(Enum.reverse(corpse_dirty), fn npc ->
        Context.Field.broadcast(state.topic, Packets.ControlNpc.dead(npc))
      end)
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
