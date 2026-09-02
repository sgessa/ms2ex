defmodule Ms2ex.MobRespawnTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field
  alias Ms2ex.Managers.Field.Npc

  @mob_id 23_991_090
  @attacker %Ms2ex.Schema.Character{id: 1, name: "Testy"}
  @cooldown_s 10
  @lethal_dmg 2000

  # minimal metadata fixture so the test runs without the game-data store
  @npc_metadata %{
    basic: %{friendly: 0, class: 0, level: 10},
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  setup do
    stub_metadata(%{"npc:#{@mob_id}" => @npc_metadata})
    :ok
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

  defp spawn_doc(cooldown \\ @cooldown_s) do
    %{
      npc_ids: [@mob_id, @mob_id],
      regen_check_time: cooldown,
      population: 2,
      position: %{x: 0.0, y: 0.0, z: 0.0},
      rotation: %{x: 0.0, y: 0.0, z: 0.0}
    }
  end

  defp load_spawn(state, doc) do
    state = Npc.load_spawn(state, doc, doc.npc_ids)
    tick(state)
  end

  defp kill(state, object_id) do
    {:reply, {:ok, _mob}, state} =
      Field.handle_call({:inflict_dmg, @attacker, %{dmg: @lethal_dmg}, object_id}, nil, state)

    state
  end

  defp kill_all(state) do
    state.npcs
    |> Map.keys()
    |> Enum.reduce(state, fn oid, state -> kill(state, oid) end)
  end

  defp tick(state) do
    {:noreply, state} = Field.handle_info(:tick_npcs, state)
    state
  end

  defp alive(state), do: Enum.count(state.npcs, fn {_oid, npc} -> not npc.dead? end)

  defp spawn_state(state), do: state.npc_spawns |> Map.values() |> hd()

  test "the first cycle fills the population" do
    state = load_spawn(base_state(), spawn_doc())
    spawn = spawn_state(state)

    assert map_size(state.npcs) == 2
    assert length(spawn.spawned_mobs) == 2
    assert Enum.all?(state.npcs, fn {_oid, npc} -> npc.spawn_point_id == spawn.id end)
    assert spawn.spawn_tick == :infinity
  end

  test "wiping the spawn schedules one respawn after the cooldown" do
    state = load_spawn(base_state(), spawn_doc())
    spawn_id = spawn_state(state).id

    state = kill_all(state)
    spawn = spawn_state(state)

    assert spawn.spawned_mobs == []
    assert is_integer(spawn.spawn_tick)
    assert_in_delta(spawn.spawn_tick - Ms2ex.sync_ticks(), @cooldown_s * 1000, 100)

    # cooldown has not elapsed yet: nothing respawns
    state = tick(state)
    assert alive(state) == 0

    # once the cooldown elapses, the population refills
    now = Ms2ex.sync_ticks()
    state = put_in(state, [:npc_spawns, spawn_id], %{spawn | spawn_tick: now - 1})
    state = tick(state)

    assert alive(state) == 2
    assert length(spawn_state(state).spawned_mobs) == 2
    assert spawn_state(state).spawn_tick == :infinity
  end

  test "a partial kill schedules the respawn at twice the cooldown" do
    state = load_spawn(base_state(), spawn_doc())
    [oid | _rest] = spawn_state(state).spawned_mobs

    state = kill(state, oid)
    spawn = spawn_state(state)

    assert length(spawn.spawned_mobs) == 1

    assert_in_delta(spawn.spawn_tick - Ms2ex.sync_ticks(), @cooldown_s * 2000, 100)
  end

  test "an earlier scheduled respawn wins over a later wipe" do
    state = load_spawn(base_state(), spawn_doc())
    [oid1, oid2] = spawn_state(state).spawned_mobs

    # first death schedules at 2x cooldown, second death (full wipe) should
    # pull the cycle in to the plain cooldown
    state = kill(state, oid1)
    state = kill(state, oid2)

    assert_in_delta(
      spawn_state(state).spawn_tick - Ms2ex.sync_ticks(),
      @cooldown_s * 1000,
      100
    )
  end

  test "a zero cooldown spawn never respawns" do
    state = load_spawn(base_state(), spawn_doc(0))
    state = kill_all(state)
    spawn = spawn_state(state)

    assert spawn.spawned_mobs == []
    assert spawn.spawn_tick == :infinity

    state = tick(state)
    assert alive(state) == 0
  end

  test "friendly spawn points load eagerly and never run spawn cycles" do
    doc = %{
      npc_list: [%{npc_id: @mob_id, count: 1}],
      regen_check_time: 0,
      population: 1,
      position: %{x: 0.0, y: 0.0, z: 0.0},
      rotation: %{x: 0.0, y: 0.0, z: 0.0}
    }

    state = Npc.load_spawn(base_state(), doc, [doc.npc_list |> hd() |> Map.get(:npc_id)])
    spawn = spawn_state(state)

    refute Map.has_key?(spawn, :spawned_mobs)
    refute Map.has_key?(spawn, :spawn_tick)
  end
end
