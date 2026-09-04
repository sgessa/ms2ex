defmodule Ms2ex.BuffStatusSwapTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Schema

  @effect_id 90_000_915
  @character_id 918_273
  @object_id 4242

  setup do
    stub_metadata(%{
      "additional-effect:#{@effect_id}_1" => %{
        property: %{
          max_count: 1,
          duration_tick: 0,
          interval_tick: 0,
          delay_tick: 0,
          keep_condition: :unlimited_duration
        },
        reset_condition: 0,
        persist_end_tick: 1,
        update: %{cancel: nil, reset_cooldown: []},
        status: %{values: %{accuracy: 3}, rates: %{}, special_values: %{}, special_rates: %{}},
        recovery: nil,
        shield: nil,
        dot: %{damage: nil, buff: nil},
        skills: [],
        tick_skills: [],
        modify_overlap: []
      }
    })

    character = %Schema.Character{
      id: @character_id,
      name: "Insignia",
      object_id: @object_id,
      map_id: 0,
      channel_id: 1,
      stats: %{accuracy_max: 82, accuracy_min: 82, accuracy_cur: 82}
    }

    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    state = %{buffs: %{}, local_id_counter: 0, topic: "buff-swap-test", map_id: 0}

    %{character: character, state: state}
  end

  defp accuracy do
    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    {character.stats.accuracy_max, character.stats.accuracy_cur}
  end

  defp add(state, character) do
    {_buff, state} = Managers.Field.Buff.add_effect_buff(@effect_id, 1, character, state)
    state
  end

  test "re-applying an effect after removing it does not stack the bonus", ctx do
    state = add(ctx.state, ctx.character)
    assert accuracy() == {85, 85}

    state = Managers.Field.Buff.remove_owner_effect(@object_id, @effect_id, state)
    assert accuracy() == {82, 82}
    assert state.buffs == %{}

    state = add(state, ctx.character)
    assert accuracy() == {85, 85}

    state = Managers.Field.Buff.remove_owner_effect(@object_id, @effect_id, state)
    assert accuracy() == {82, 82}
    assert state.buffs == %{}
  end

  # a stale snapshot pushed back through {:update, ...} silently reverted the
  # stat change a buff removal had just made
  test "updating the character does not resurrect a removed buff's bonus", ctx do
    state = add(ctx.state, ctx.character)
    assert accuracy() == {85, 85}

    {:ok, buffed} = Managers.Character.call(@character_id, :lookup)

    _state = Managers.Field.Buff.remove_owner_effect(@object_id, @effect_id, state)
    assert accuracy() == {82, 82}

    Managers.Character.call(@character_id, {:update, buffed})
    assert accuracy() == {85, 85}, "the snapshot is expected to clobber; guard the ordering"
  end
end
