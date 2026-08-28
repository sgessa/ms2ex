defmodule Ms2ex.BuffChainTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Types

  @mob_id 23_991_090
  @oid 50_000_086
  @caster %Ms2ex.Schema.Character{id: 1, name: "Caster", object_id: 99}

  # Ice Spear chain fixtures mirroring the projected effect documents:
  #  - 10300051 chill: stacks to 6, fires the frozen (10300052), slow
  #  - 10300052 frozen: 1s stun, cancels the chill it replaces
  #  - 10300182 marker: 10s, modify_overlap bumps the frost (10300271)
  #  - 10300271 frost: max 10 stacks, fires 10300275/10300272 at the cap
  #  - 10300275/10300272: fired at the frost cap; each applies 10300273
  defp seed_effects do
    base = %{
      property: %{max_count: 1, duration_tick: 1000, interval_tick: 0, delay_tick: 0},
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

    chill = %{
      base
      | property: %{max_count: 6, duration_tick: 3000, interval_tick: 0, delay_tick: 0},
        skills: [%{id: 10_300_052, level: 1}]
    }

    frozen = %{
      base
      | property: %{
          max_count: 1,
          duration_tick: 1000,
          interval_tick: 0,
          delay_tick: 0,
          stun: 3,
          category: 7
        },
        update: %{cancel: %{ids: [10_300_051], check_same_caster: false}, reset_cooldown: []}
    }

    marker = %{
      base
      | property: %{max_count: 1, duration_tick: 10_000, interval_tick: 0, delay_tick: 0},
        modify_overlap: [%{id: 10_300_271, offset: 1}]
    }

    frost = %{
      base
      | property: %{max_count: 10, duration_tick: 20_000, interval_tick: 1000, delay_tick: 0},
        dot: %{
          damage: %{
            type: 2,
            element: 2,
            rate: 0.93,
            hp_value: 0,
            sp_value: 0,
            ep_value: 0,
            damage_by_target_max_hp: 0.0,
            recover_hp_by_damage: 0.0,
            is_const_damage: false,
            not_kill: false
          },
          buff: nil
        },
        skills: [%{id: 10_300_275, level: 1}, %{id: 10_300_272, level: 1}]
    }

    fire = %{
      base
      | property: %{max_count: 1, duration_tick: 5000, interval_tick: 500, delay_tick: 0},
        skills: [%{id: 10_300_273, level: 1}]
    }

    effects = [
      {10_300_051, chill},
      {10_300_052, frozen},
      {10_300_182, marker},
      {10_300_271, frost},
      {10_300_275, fire},
      {10_300_272, fire}
    ]

    Enum.each(effects, fn {id, meta} ->
      :ets.insert(:metadata, {"additional-effect:#{id}_1", {:ok, meta}})
    end)
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
      topic: "test-topic",
      map_id: nil
    }

    %{mob: mob, state: state}
  end

  defp fetch_buff(state, effect_id) do
    state.buffs
    |> Enum.find_value(fn {{_owner, effect, _caster}, buff_id} ->
      if effect == effect_id, do: Managers.Buff.fetch(buff_id)
    end)
  end

  defp apply(state, mob, effect_id, overlap) do
    {_buff, state} = Managers.Field.Buff.add_mob_buff(@caster, effect_id, 1, mob, state, overlap)
    state
  end

  test "chill stacks via overlap_count and fires the frozen, which cancels the chill", ctx do
    state =
      Enum.reduce(1..6, ctx.state, fn _i, state ->
        apply(state, ctx.mob, 10_300_051, 1)
      end)

    chill = fetch_buff(state, 10_300_051)
    frozen = fetch_buff(state, 10_300_052)

    assert chill == nil, "the frozen must cancel the chill"
    refute is_nil(frozen), "chill must fire the frozen at its stack cap"
  end

  test "the marker bumps the frost stacks via modify_overlap", ctx do
    state = apply(ctx.state, ctx.mob, 10_300_271, 1)
    frost = fetch_buff(state, 10_300_271)
    assert frost.stacks == 1

    state = apply(state, ctx.mob, 10_300_182, 1)
    frost = fetch_buff(state, 10_300_271)

    assert frost.stacks == 2, "marker modify_overlap must bump the frost by 1"
  end

  test "frost at its stack cap fires its skills on the owner", ctx do
    state =
      Enum.reduce(1..10, ctx.state, fn _i, state ->
        apply(state, ctx.mob, 10_300_271, 1)
      end)

    assert fetch_buff(state, 10_300_275), "frost must fire 10300275 at 10 stacks"
    assert fetch_buff(state, 10_300_272), "frost must fire 10300272 at 10 stacks"
  end
end
