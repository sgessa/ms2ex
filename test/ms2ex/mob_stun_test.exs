defmodule Ms2ex.MobStunTest do
  # buffs live in globally-named agents (buff:<object_id>) shared across
  # test runs — keep this suite out of the async pool so concurrent buff
  # tests can't stop each other's agents
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field.Npc.Battle
  alias Ms2ex.Managers.Field.Buff
  alias Ms2ex.Types

  @stun_effect 10_300_090
  @plain_effect 10_300_091
  @mob_id 23_991_090
  @oid 50_000_086
  @caster %Ms2ex.Schema.Character{id: 1, name: "Caster", object_id: 99}

  defp seed_effects do
    base = %{
      property: %{max_count: 1, duration_tick: 5000, interval_tick: 0, delay_tick: 0},
      reset_condition: 0,
      persist_end_tick: 0,
      update: %{cancel: nil, reset_cooldown: []},
      status: %{values: %{}, rates: %{}, special_values: %{}, special_rates: %{}},
      recovery: nil,
      shield: nil,
      dot: %{damage: nil, buff: nil},
      skills: [],
      tick_skills: [],
      modify_overlap: []
    }

    # the motion data counts stun in whole seconds: a 2s stun
    stun = %{base | property: %{max_count: 1, duration_tick: 5000, stun: 2}}

    stub_metadata(%{
      "additional-effect:#{@stun_effect}_1" => stun,
      "additional-effect:#{@plain_effect}_1" => base
    })
  end

  setup do
    seed_effects()

    npc =
      Types.Npc.new(%{
        id: @mob_id,
        metadata: %{basic: %{friendly: 0}, stat: %{stats: %{health: 1000}}}
      })

    mob =
      Types.FieldNpc.new(%{
        object_id: @oid,
        spawn_point_id: nil,
        npc: npc,
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        field: self()
      })

    state = %{
      buffs: %{},
      local_id_counter: 0,
      npcs: %{@oid => mob},
      players: %{},
      player_positions: %{},
      tombstones: %{},
      topic: "test-topic",
      map_id: nil
    }

    %{mob: mob, state: state}
  end

  defp apply_effect(state, effect_id) do
    {_buff, state} = Buff.add_mob_buff(@caster, effect_id, 1, state.npcs[@oid], state, 0)
    state
  end

  defp chasing_mob(ctx, now, overrides \\ %{}) do
    battle =
      Map.merge(
        %{
          mode: :chase,
          target_id: @caster.id,
          target_object_id: @caster.object_id,
          stop_range: 150,
          path: nil,
          path_index: 1,
          goal: nil,
          next_repath_at: now,
          last_move_at: now,
          keep_until: now + 10_000,
          no_route_since: nil,
          cast: nil,
          swing_until: nil,
          next_attack_at: now,
          attack_counter: 0,
          hit_event: nil
        },
        overrides
      )

    %{ctx.mob | battle: battle, velocity: {10.0, 0.0, 0.0}}
  end

  test "a stun buff roots the mob for the buff window: deadline set, swing dropped, velocity zeroed",
       ctx do
    state = apply_effect(ctx.state, @stun_effect)

    mob = state.npcs[@oid]

    # the hold covers the buff's whole window — the client plays the stun
    # animation from the buff's start to end tick
    buff = state.buffs |> Map.values() |> hd() |> Ms2ex.Managers.Buff.fetch()
    assert mob.stunned_until == buff.end_tick
    assert mob.velocity == {0, 0, 0}
  end

  test "a stun interrupts the in-flight swing", ctx do
    now = Ms2ex.sync_ticks()

    state =
      ctx.state
      |> put_in([:npcs, @oid], chasing_mob(ctx, now, %{cast: %{skill_id: 1, hit_at: now + 500}}))
      |> apply_effect(@stun_effect)

    mob = state.npcs[@oid]
    assert mob.battle.cast == nil
    assert mob.battle.mode == :chase
  end

  test "a non-stun buff never roots the mob", ctx do
    state = apply_effect(ctx.state, @plain_effect)

    assert state.npcs[@oid].stunned_until == 0
  end

  test "the battle tick holds a stunned mob still", ctx do
    now = Ms2ex.sync_ticks()
    mob = %{chasing_mob(ctx, now) | stunned_until: now + 2000}

    {ticked, hits} = Battle.tick(mob, ctx.state, now + 100)

    assert hits == []
    assert ticked.battle == mob.battle
    assert ticked.position == mob.position
  end

  test "the mob resumes fighting once the stun expires", ctx do
    now = Ms2ex.sync_ticks()
    mob = %{chasing_mob(ctx, now) | stunned_until: now + 2000}

    # the engagement hold is long gone and the target left the field: a
    # tick past the stun processes the battle again — the mob, still at
    # its origin, disengages straight back to idle
    {ticked, hits} = Battle.tick(mob, ctx.state, now + 60_000)

    assert hits == []
    assert ticked.battle == nil
  end

  test "removing the stun releases the mob immediately", ctx do
    state = apply_effect(ctx.state, @stun_effect)
    assert state.npcs[@oid].stunned_until > 0

    buff_id = state.buffs |> Map.values() |> hd()
    state = Buff.remove_buff(buff_id, state, true)

    assert state.npcs[@oid].stunned_until == 0
  end
end
