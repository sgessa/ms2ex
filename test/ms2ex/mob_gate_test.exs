defmodule Ms2ex.MobGateTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field
  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader

  @mob_id 29_000_128
  @attacker %Ms2ex.Schema.Character{id: 1, name: "Testy"}
  @lethal_dmg 2000

  @npc_metadata %{
    basic: %{friendly: 0, class: 0, level: 1},
    stat: %{stats: %{health: 5}}
  }

  @gate %{
    spawn_point_id: 101,
    meshes: [
      %{id: 1000, minimap_invisible: true, scale: 1.0},
      %{id: 2000, minimap_invisible: false, scale: 2.0}
    ],
    guide_event: 260
  }

  setup do
    stub_metadata(%{"npc:#{@mob_id}" => @npc_metadata})
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "test-topic")
    :ok
  end

  test "update_mesh serializes the trigger mesh state change" do
    bytes = Packets.Trigger.hide_mesh(%{id: 1000, minimap_invisible: true, scale: 1.0})

    {opcode, packet} = get_short(bytes)
    {command, packet} = get_byte(packet)
    {mesh_id, packet} = get_int(packet)
    {visible, packet} = get_bool(packet)
    {minimap, packet} = get_bool(packet)
    {fade, packet} = get_int(packet)
    {label, packet} = get_ustring(packet)
    {scale, packet} = get_float(packet)

    assert {opcode, command, mesh_id} == {0x4F, 0x3, 1000}
    assert {visible, minimap} == {false, true}
    assert {fade, label, scale} == {0, "", 1.0}
    assert packet == <<>>
  end

  test "guide_event serializes the ui guide step" do
    assert <<0x4F::little-16, 0x8, 0x1, 260::little-32>> = Packets.Trigger.guide_event(260)
  end

  test "load lists already-hidden meshes as dropped" do
    bytes =
      Packets.Trigger.load([
        %{id: 1000, minimap_invisible: true, scale: 1.0},
        %{id: 2000, minimap_invisible: false, scale: 2.0}
      ])

    assert <<0x4F::little-16, 0x2, 2::little-32>> <> rest = bytes

    assert <<1000::little-32, 0, 1, 0::little-32, 0::little-16, 1.0::little-float-32,
             2000::little-32, 0, 0, 0::little-32, 0::little-16, 2.0::little-float-32>> = rest
  end

  test "killing the last mob of a gated spawn hides the barrier meshes" do
    state = gated_state()

    {_object_id, state} = kill_only_mob(state)

    assert [trigger_1000, trigger_2000] = trigger_pushes()
    assert <<0x4F::little-16, 0x3, 1000::little-32, 0, 1>> <> _ = trigger_1000
    assert <<0x4F::little-16, 0x3, 2000::little-32, 0, 0>> <> _ = trigger_2000

    # the gate stays latched open
    assert MapSet.member?(state.opened_gates, @gate.spawn_point_id)
  end

  test "the gate only opens when every mob of the spawn is dead" do
    state = gated_state(%{npc_ids: [@mob_id, @mob_id], population: 2})

    state = kill_one(state)

    assert [] == trigger_pushes()
    assert Enum.count(state.npcs, fn {_oid, npc} -> not npc.dead? end) == 1
  end

  test "a respawned guard does not re-broadcast the mesh hides" do
    {_object_id, state0} = gated_state() |> kill_only_mob()
    assert length(trigger_pushes()) == 2

    # run the respawn cycle, then kill the guard again
    state0
    |> force_respawn()
    |> kill_only_mob()

    assert [] == trigger_pushes()
  end

  test "spawns without a gate never broadcast trigger updates" do
    state =
      base_state()
      |> Map.put(:mob_gates, %{})
      |> load_spawn(spawn_doc())

    {_object_id, _state} = kill_only_mob(state)

    assert [] == trigger_pushes()
  end

  defp base_state do
    %{
      npcs: %{},
      npc_spawns: %{},
      players: %{},
      topic: "test-topic",
      map_id: nil,
      local_id_counter: 50_000_000
    }
  end

  defp spawn_doc do
    %{
      npc_ids: [@mob_id],
      regen_check_time: 10,
      population: 1,
      position: %{x: 0.0, y: 0.0, z: 0.0},
      rotation: %{x: 0.0, y: 0.0, z: 0.0},
      spawn_point_id: @gate.spawn_point_id
    }
  end

  defp gated_state(overrides \\ %{}) do
    doc = Map.merge(spawn_doc(), overrides)

    base_state()
    |> Map.put(:mob_gates, %{@gate.spawn_point_id => @gate})
    |> Map.put(:opened_gates, MapSet.new())
    |> load_spawn(doc)
  end

  defp load_spawn(state, doc) do
    state = Npc.load_spawn(state, doc, doc.npc_ids)
    tick(state)
  end

  defp tick(state) do
    {:noreply, state} = Field.handle_info(:tick_npcs, state)
    state
  end

  defp kill_only_mob(state) do
    [object_id] = Map.keys(state.npcs)
    {object_id, kill_one(state)}
  end

  defp kill_one(state) do
    object_id = state.npcs |> Map.keys() |> Enum.find(fn oid -> not state.npcs[oid].dead? end)

    {:reply, {:ok, _mob}, state} =
      Field.handle_call({:inflict_dmg, @attacker, %{dmg: @lethal_dmg}, object_id}, nil, state)

    state
  end

  # moves the spawn's due tick into the past so the next npc tick refills
  # it; the old corpse is removed the way its removal timer would
  defp force_respawn(state) do
    [{spawn_id, _spawn}] = Enum.to_list(state.npc_spawns)
    state = put_in(state, [:npc_spawns, spawn_id, :spawn_tick], Ms2ex.sync_ticks() - 1)

    state
    |> tick()
    |> remove_corpses()
  end

  defp remove_corpses(state) do
    Enum.reduce(state.npcs, state, fn
      {_oid, %{dead?: true} = npc}, state ->
        {:noreply, state} = Field.handle_info({:remove_npc, npc}, state)
        state

      {_oid, _npc}, state ->
        state
    end)
  end

  # collects trigger-update pushes from the field topic, draining the other
  # broadcasts a mob death produces (stats, dead control)
  defp trigger_pushes do
    receive_do(:trigger, [])
  end

  defp receive_do(:trigger, acc) do
    receive do
      {:push, <<0x4F::little-16, 0x3, _::binary>> = packet} ->
        receive_do(:trigger, [packet | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
