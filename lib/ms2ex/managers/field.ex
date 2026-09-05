defmodule Ms2ex.Managers.Field do
  use GenServer

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Types.Npc

  alias Ms2ex.Managers.Field

  @updates_intval 1000
  @npc_tick_intval 15
  @banner_tick_intval :timer.seconds(30)

  # one app-wide counter feeds players and mounts, while each field instance
  # owns a local counter for npcs, portals, spawn points and items
  @local_id_counter 50_000_000

  def next_local_id(state) do
    id = state.local_id_counter + 1
    {id, %{state | local_id_counter: id}}
  end

  defp banners(map_id) do
    banners = Ms2ex.Storage.Tables.Banners.for_map(map_id)
    slots = Ms2ex.Context.BannerSlots.list(Enum.map(banners, & &1.id))

    banners
    |> Map.new(fn banner ->
      {banner.id, Map.put(banner, :slots, Enum.filter(slots, &(&1.banner_id == banner.id)))}
    end)
  end

  defp activate_banners(state) do
    now = DateTime.utc_now()
    state = expire_banner_slots(state, now)

    {banners, changed} =
      Enum.map_reduce(state.banners, [], fn {banner_id, banner}, changed ->
        active_slot = Enum.find(banner.slots, &current_slot?(&1, now))

        slots =
          Enum.map(banner.slots, &update_slot_active(&1, active_slot, now))

        updated_banner = %{banner | slots: slots}
        changed = if slots == banner.slots, do: changed, else: [updated_banner | changed]
        {{banner_id, updated_banner}, changed}
      end)

    {%{state | banners: Map.new(banners)}, changed}
  end

  defp expire_banner_slots(state, now) do
    {banners, expired_slots} =
      Enum.map_reduce(state.banners, [], fn {banner_id, banner}, expired_slots ->
        {expired, slots} = Enum.split_with(banner.slots, &expired?(&1, now))
        {{banner_id, %{banner | slots: slots}}, expired ++ expired_slots}
      end)

    case expired_slots do
      [] ->
        state

      _ ->
        Ms2ex.Context.BannerSlots.expire(expired_slots)
        %{state | banners: Map.new(banners)}
    end
  end

  defp current_slot?(
         %{starts_at: %DateTime{} = starts_at, ends_at: %DateTime{} = ends_at} = slot,
         now
       ) do
    not is_nil(slot.ugc) and DateTime.compare(starts_at, now) != :gt and
      DateTime.compare(now, ends_at) == :lt
  end

  defp current_slot?(slot, now) do
    (slot.ugc && slot.date == now.year * 10_000 + now.month * 100 + now.day) and
      slot.hour == now.hour
  end

  defp update_slot_active(slot, nil, _now), do: Map.put(slot, :active, false)

  defp update_slot_active(slot, %{id: id}, now) when slot.id == id do
    slot
    |> Map.put(:active, true)
    |> Map.put_new(:activated_at, now)
  end

  defp update_slot_active(slot, _active_slot, _now), do: Map.put(slot, :active, false)

  defp expired?(%{ends_at: %DateTime{} = ends_at}, now), do: DateTime.compare(now, ends_at) != :lt
  defp expired?(_slot, _now), do: false

  defp attach_banner(banner, character, slot_ids, ugc) do
    with true <- Enum.all?(slot_ids, &attachable_slot?(banner.slots, character.id, &1)) do
      {:ok, %{banner | slots: Enum.map(banner.slots, &put_slot_ugc(&1, slot_ids, ugc))}}
    end
  end

  defp confirm_banner(banner, resource_id, path) do
    with true <- Enum.any?(banner.slots, &slot_resource?(&1, resource_id)) do
      {:ok, %{banner | slots: Enum.map(banner.slots, &put_slot_path(&1, resource_id, path))}}
    end
  end

  defp attachable_slot?(slots, character_id, id) do
    Enum.any?(slots, &(&1.id == id and &1.character_id == character_id and is_nil(&1.ugc)))
  end

  defp slot_resource?(slot, resource_id), do: get_in(slot, [:ugc, :id]) == resource_id

  defp put_slot_ugc(slot, ids, ugc) do
    if slot.id in ids, do: Map.put(slot, :ugc, ugc), else: slot
  end

  defp put_slot_path(slot, resource_id, path) do
    if slot_resource?(slot, resource_id), do: put_in(slot, [:ugc, :url], path), else: slot
  end

  defp find_confirmed_banner(banners, resource_id, path) do
    Enum.find_value(banners, fn {banner_id, banner} ->
      case confirm_banner(banner, resource_id, path) do
        {:ok, banner} -> {banner_id, banner}
        _ -> nil
      end
    end)
  end

  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    field_name = Context.Field.field_name(map_id, channel_id)

    {local_id_counter, portals} = Field.Portal.load(map_id, @local_id_counter)
    interactable = Field.InteractObject.load(map_id)

    state = %{
      buffs: %{},
      banners: banners(map_id),
      channel_id: channel_id,
      local_id_counter: local_id_counter,
      interactable: interactable,
      instruments: %{},
      items: %{},
      map_id: map_id,
      mob_gates: Storage.Maps.get_mob_gates(map_id),
      opened_gates: MapSet.new(),
      hidden_meshes: [],
      mounts: %{},
      npcs: %{},
      npc_spawns: %{},
      performance: nil,
      players: %{},
      portals: portals,
      regions: %{},
      sessions: %{},
      stage: MapSet.new(),
      tombstones: %{},
      topic: field_name
    }

    send(self(), :load_npc_spawns)
    send(self(), :tick_npcs)
    send(self(), :send_updates)
    send(self(), :tick_banners)

    {:ok, state, {:continue, {:add_character, character}}}
  end

  def handle_continue({:add_character, character}, state),
    do: {:noreply, Field.Character.add_character(character, state)}

  def handle_call({:add_character, character}, _from, state),
    do: {:reply, {:ok, self()}, Field.Character.add_character(character, state)}

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

  def handle_call({:hit_tombstone, object_id, hits}, _from, state) do
    case Field.Tombstone.hit(object_id, hits, state) do
      {:ok, state} ->
        {:reply, :ok, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:add_instrument, instrument}, _from, state) do
    {instrument, state} = Field.Instrument.add(instrument, state)
    {:reply, {:ok, instrument}, state}
  end

  def handle_call(:next_object_id, _from, state) do
    {object_id, state} = next_local_id(state)
    {:reply, {:ok, object_id}, state}
  end

  def handle_call({:lookup_instrument, character_id}, _from, state) do
    case Field.Instrument.get(character_id, state) do
      nil -> {:reply, :error, state}
      instrument -> {:reply, {:ok, instrument}, state}
    end
  end

  def handle_call({:remove_instrument, character_id}, _from, state) do
    case Field.Instrument.get(character_id, state) do
      nil -> {:reply, :error, state}
      instrument -> {:reply, {:ok, instrument}, Field.Instrument.remove(character_id, state)}
    end
  end

  def handle_call({:reserve_banner_slots, character, banner_id, reservations}, _from, state) do
    case Map.fetch(state.banners, banner_id) do
      :error ->
        {:reply, :error, state}

      {:ok, banner} ->
        case Ms2ex.Context.BannerSlots.reserve(character, banner_id, reservations) do
          {:ok, slots} ->
            banners = Map.put(state.banners, banner_id, %{banner | slots: banner.slots ++ slots})
            {:reply, {:ok, slots}, %{state | banners: banners}}

          :error ->
            {:reply, :error, state}
        end
    end
  end

  def handle_call({:attach_banner, character, banner_id, slot_ids, ugc}, _from, state) do
    with {:ok, banner} <- Map.fetch(state.banners, banner_id),
         {:ok, banner} <- attach_banner(banner, character, slot_ids, ugc),
         {_count, _slots} <- Ms2ex.Context.BannerSlots.attach(slot_ids, ugc) do
      {:reply, {:ok, banner}, %{state | banners: Map.put(state.banners, banner_id, banner)}}
    else
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:confirm_banner, resource_id, path}, _from, state) do
    case find_confirmed_banner(state.banners, resource_id, path) do
      nil ->
        {:reply, :error, state}

      {banner_id, banner} ->
        {:reply, {:ok, banner}, %{state | banners: Map.put(state.banners, banner_id, banner)}}
    end
  end

  def handle_call(:banners, _from, state), do: {:reply, Map.values(state.banners), state}

  def handle_call(:performance_stage?, _from, state),
    do: {:reply, Field.PerformanceStage.stage?(state), state}

  def handle_call({:interact_object, character, uuid}, _from, state) do
    case Field.InteractObject.react(character, uuid, state) do
      {:ok, object, state} ->
        {:reply, {:ok, object}, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:add_region_skill, skill_cast}, _from, state),
    do: {:reply, :ok, Field.RegionSkill.add(skill_cast, state)}

  def handle_call({:add_buff, skill_cast, skill, character}, _from, state) do
    case Field.Buff.add_buff(skill_cast, skill, character, state) do
      {nil, state} ->
        {:reply, :error, state}

      {buff, state} ->
        {:reply, {:ok, buff}, state}
    end
  end

  def handle_call({:add_effect_buff, effect_id, effect_level, character}, from, state),
    do: handle_call({:add_effect_buff, effect_id, effect_level, character, []}, from, state)

  def handle_call({:add_effect_buff, effect_id, effect_level, character, opts}, _from, state) do
    {_buff, state} =
      Field.Buff.add_effect_buff(effect_id, effect_level, character, state, 0, opts)

    {:reply, :ok, state}
  end

  def handle_call({:has_buff?, owner_object_id, effect_id}, _from, state),
    do: {:reply, Field.Buff.owner_has_buff?(owner_object_id, effect_id, state), state}

  def handle_call({:has_buff_event?, owner_object_id, event_type}, _from, state),
    do: {:reply, Field.Buff.owner_has_buff_event?(owner_object_id, event_type, state), state}

  def handle_call({:modify_buff_duration, owner_object_id, effect_id, modify_tick}, _from, state),
    do: {:reply, :ok, Field.Buff.modify_duration(owner_object_id, effect_id, modify_tick, state)}

  def handle_call({:remove_effect_buff, owner_object_id, effect_id}, _from, state),
    do: {:reply, :ok, Field.Buff.remove_owner_effect(owner_object_id, effect_id, state)}

  def handle_call({:lookup_npc, object_id}, _from, state) do
    case Map.get(state.npcs, object_id) do
      nil -> {:reply, :error, state}
      npc -> {:reply, {:ok, npc}, state}
    end
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}, object_id}, _from, state) do
    case Field.Npc.damage(state, attacker, dmg, object_id) do
      {:ok, field_npc, state} ->
        {:reply, {:ok, field_npc}, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:apply_skill_effects, skill_cast, mob_id}, _from, state),
    do: {:reply, :ok, Field.Npc.apply_skill_effects(state, skill_cast, mob_id)}

  def handle_cast({:drop_item, source, item}, state),
    do: {:noreply, Field.Item.drop_item(source, item, state)}

  def handle_cast({:drop_item, source, item, position}, state),
    do: {:noreply, Field.Item.drop_item(source, item, position, state)}

  def handle_cast({:add_mob_drop, %FieldNpc{} = mob, %Schema.Item{} = item, receiver}, state),
    do: {:noreply, Field.Item.add_mob_drop(mob, item, receiver, state)}

  # a dead player's tombstone is announced with its hit counts so clients can
  # render the revive gauge and hit it; the owner is keyed by character id for
  # the revive lookup
  def handle_cast({:add_tombstone, character}, state),
    do: {:noreply, Field.Tombstone.add(character, state)}

  def handle_cast({:clear_tombstone, character_id}, state),
    do: {:noreply, Field.Tombstone.clear(character_id, state)}

  def handle_cast({:remove_tombstone, character_id}, state),
    do: {:noreply, Field.Tombstone.remove(character_id, state)}

  # buffs die with their owner; remove every buff owned by the object id
  def handle_cast({:remove_owner_buffs, owner_object_id}, state),
    do: {:noreply, Field.Buff.remove_owner_buffs(owner_object_id, state)}

  def handle_cast({:start_performance, character}, state),
    do: {:noreply, Field.PerformanceStage.start(character, state)}

  def handle_cast({:end_performance, character_id}, state),
    do: {:noreply, Field.PerformanceStage.stop(character_id, state)}

  def handle_cast({:toggle_stage, character}, state),
    do: {:noreply, Field.PerformanceStage.toggle_stage(character, state)}

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

  def handle_info({:add_npc_spawn, npc_spawn, npc_ids}, state),
    do: {:noreply, Field.Npc.load_spawn(state, npc_spawn, npc_ids)}

  def handle_info({:add_npc, npc_id, npc_spawn}, state),
    do: {:noreply, Field.Npc.load_npc(state, npc_id, npc_spawn)}

  def handle_info({:add_mob, %Npc{} = npc, position}, state),
    do: {:noreply, Field.Npc.load_npc(state, npc, %{position: position, rotation: nil})}

  def handle_info({:remove_npc, field_npc}, state) do
    Context.Field.broadcast(field_npc.field, Packets.FieldRemoveNpc.bytes(field_npc.object_id))
    Context.Field.broadcast(field_npc.field, Packets.ProxyGameObj.remove_npc(field_npc))

    {:noreply, Field.Npc.remove_npc(field_npc, state)}
  end

  def handle_info(:tick_npcs, state) do
    Process.send_after(self(), :tick_npcs, @npc_tick_intval)
    state = Field.InteractObject.tick(state)
    {:noreply, Field.Npc.tick(state)}
  end

  def handle_info({:region_tick, source_id}, state),
    do: {:noreply, Field.RegionSkill.maybe_tick(source_id, state)}

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
    Field.Character.leave_battle_stance(character)
    {:noreply, state}
  end

  def handle_info({:end_performance, character_id}, state),
    do: {:noreply, Field.PerformanceStage.release(character_id, state)}

  def handle_info(:send_updates, state) do
    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, Field.Character.send_updates(state)}
  end

  def handle_info(:tick_banners, state) do
    Process.send_after(self(), :tick_banners, @banner_tick_intval)
    {state, changed} = activate_banners(state)
    Enum.each(changed, &Context.Field.broadcast(state.topic, Packets.Ugc.activate_banner(&1)))
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
