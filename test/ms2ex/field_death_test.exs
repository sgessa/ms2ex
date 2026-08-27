defmodule Ms2ex.FieldDeathTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Managers.Field
  alias Ms2ex.Types

  @mob_id 23_991_090
  @oid 50_000_086
  @attacker %Ms2ex.Schema.Character{id: 1, name: "Testy"}

  # minimal metadata fixture so the test runs without the game-data store
  @npc_metadata %{
    basic: %{friendly: 0, class: 3},
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  setup do
    # seed the metadata cache directly (no Redis / game data needed)
    :ets.insert(:metadata, {"npc:#{@mob_id}", {:ok, @npc_metadata}})

    # field-drop item metadata (mesos, merets, spirit orbs, stamina) so the
    # death/damage reward paths can build items without the game-data store
    for item_id <- [90_000_001, 90_000_004, 90_000_009, 90_000_010] do
      :ets.insert(:metadata, {"item:#{item_id}", {:ok, %{limit: %{level: 1}, slot_names: []}}})
    end

    npc = Types.Npc.new(%{id: @mob_id, metadata: @npc_metadata})

    field_npc =
      Types.FieldNpc.new(%{
        object_id: @oid,
        spawn_point_id: nil,
        npc: npc,
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        field: self()
      })

    %{field_npc: field_npc, max_hp: field_npc.stats.health.current}
  end

  defp state_with(field_npc),
    do: %{npcs: %{@oid => field_npc}, players: %{}, topic: "test-topic", map_id: nil}

  defp hit(state, dmg) do
    {:reply, {:ok, mob}, new_state} =
      Field.handle_call({:inflict_dmg, @attacker, %{dmg: dmg}, @oid}, nil, state)

    {mob, new_state}
  end

  defp tick(state) do
    {:noreply, new_state} = Field.handle_info(:tick_npcs, state)
    new_state
  end

  defp stored(state), do: state.npcs[@oid]

  test "lethal hit kills exactly once; later hits observe the corpse", ctx do
    state = state_with(ctx.field_npc)

    {mob, state} = hit(state, ctx.max_hp * 2)
    assert mob.dead?, "single overkill hit should kill"
    assert stored(state).dead?

    {mob, state} = hit(state, 100)
    assert mob.dead?, "follow-up hit must still see the dead mob"
    assert stored(state).dead?

    state = tick(state)
    {_mob, state} = hit(state, 100)
    assert stored(state).dead?, "death flag lost across a tick cycle"
  end

  test "many sub-lethal hits kill once and never re-kill", ctx do
    state = state_with(ctx.field_npc)
    per_hit = div(ctx.max_hp, 10)

    {deaths, state} =
      Enum.reduce(1..20, {0, state}, fn _i, {deaths, state} ->
        was_dead = stored(state).dead?
        {mob, state} = hit(state, per_hit)

        deaths =
          cond do
            not was_dead and mob.dead? -> deaths + 1
            was_dead and mob.dead? -> deaths
            true -> deaths
          end

        {deaths, tick(state)}
      end)

    assert stored(state).dead?
    assert deaths == 1, "expected exactly one death transition, got #{deaths}"
  end
end
