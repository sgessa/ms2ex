defmodule Ms2ex.CharacterConfigManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  setup do
    account =
      Repo.insert!(%Schema.Account{
        username: "cfgm_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Cfgm#{System.unique_integer([:positive])}",
        job: :knight,
        level: 1,
        map_id: 1,
        skin_color: {}
      })

    Repo.insert!(%Schema.CharacterConfig{character_id: character.id})

    empty = List.duplicate(%Types.QuickSlot{}, 25)

    hot_bars = [
      Repo.insert!(%Schema.HotBar{character_id: character.id, active: true, quick_slots: empty}),
      Repo.insert!(%Schema.HotBar{character_id: character.id, active: false, quick_slots: empty})
    ]

    state = %{
      character_id: character.id,
      hot_bars: hot_bars,
      config: Context.CharacterConfigs.get(character.id)
    }

    %{character: character, state: state}
  end

  test "fresh? mirrors the bars until a slot is placed", %{state: state} do
    {:reply, fresh, state} = Managers.CharacterConfig.handle_call(:fresh?, :from, state)
    assert fresh

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 10_300_001}, 4},
        :from,
        state
      )

    {:reply, fresh, _state} = Managers.CharacterConfig.handle_call(:fresh?, :from, state)
    refute fresh
  end

  test "quick-slot moves swap positions and persist", %{character: character, state: state} do
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 10_300_001}, 4},
        :from,
        state
      )

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 10_300_041}, 5},
        :from,
        state
      )

    # moving the first skill onto the second swaps the two positions
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 10_300_001}, 5},
        :from,
        state
      )

    active = Enum.find(state.hot_bars, & &1.active)
    assert Enum.at(active.quick_slots, 4).skill_id == 10_300_041
    assert Enum.at(active.quick_slots, 5).skill_id == 10_300_001

    persisted = Context.HotBars.list(%Schema.Character{id: character.id}) |> Enum.find(& &1.active)
    assert Enum.at(persisted.quick_slots, 5).skill_id == 10_300_001
  end

  test "moving onto an unknown hot bar replies with an error", %{state: state} do
    {:reply, reply, ^state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 9, %Types.QuickSlot{skill_id: 1}, 1},
        :from,
        state
      )

    assert reply == :error
  end

  test "removing an unknown quick slot replies with an error", %{state: state} do
    {:reply, reply, ^state} =
      Managers.CharacterConfig.handle_call({:remove_quick_slot, 0, 123_456, 0}, :from, state)

    assert reply == :error
  end

  test "removing a quick slot clears it and persists", %{character: character, state: state} do
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 90_000_038, item_id: 20_000_028, item_uid: 7}, 6},
        :from,
        state
      )

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call({:remove_quick_slot, 0, 90_000_038, 7}, :from, state)

    active = Enum.find(state.hot_bars, & &1.active)
    assert %Types.QuickSlot{} = Enum.at(active.quick_slots, 6)

    persisted = Context.HotBars.list(%Schema.Character{id: character.id}) |> Enum.find(& &1.active)
    assert %Types.QuickSlot{} = Enum.at(persisted.quick_slots, 6)
  end

  test "a move target outside the assignable range falls back to the first free slot", %{
    state: state
  } do
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 10_300_001}, 4},
        :from,
        state
      )

    # slot 4 is taken, so the placement order's next free slot is 5
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 10_300_041}, -1},
        :from,
        state
      )

    active = Enum.find(state.hot_bars, & &1.active)
    assert Enum.at(active.quick_slots, 5).skill_id == 10_300_041
  end

  test "a move onto a full bar replaces slot 0", %{state: state} do
    full_bar = Enum.at(state.hot_bars, 0)
    full_slots = Enum.map(1..25, &%Types.QuickSlot{skill_id: &1})
    full_bar = %{full_bar | quick_slots: full_slots}

    state = %{state | hot_bars: List.replace_at(state.hot_bars, 0, full_bar)}

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:move_quick_slot, 0, %Types.QuickSlot{skill_id: 99_999_999}, 30},
        :from,
        state
      )

    active = Enum.find(state.hot_bars, & &1.active)
    assert Enum.at(active.quick_slots, 0).skill_id == 99_999_999
  end

  test "the active hot bar switch persists", %{character: character, state: state} do
    {:reply, :ok, state} = Managers.CharacterConfig.handle_call({:set_active_bar, 1}, :from, state)

    bars = state.hot_bars
    refute Enum.at(bars, 0).active
    assert Enum.at(bars, 1).active

    persisted = Context.HotBars.list(%Schema.Character{id: character.id})
    assert Enum.find(persisted, & &1.active).id == Enum.at(persisted, 1).id
  end

  test "key binds merge by key code and persist", %{character: character, state: state} do
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:merge_key_binds, %{18 => %Types.KeyBind{key_code: 18, option_type: 1, option_guid: 500_009}}},
        :from,
        state
      )

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call(
        {:merge_key_binds,
         %{
           18 => %Types.KeyBind{key_code: 18, option_type: 1, option_guid: 500_010},
           19 => %Types.KeyBind{key_code: 19, option_type: 1, option_guid: 500_011}
         }},
        :from,
        state
      )

    {:reply, binds, _state} = Managers.CharacterConfig.handle_call(:key_binds, :from, state)
    assert map_size(binds) == 2
    assert binds[18].option_guid == 500_010
    assert binds[19].option_guid == 500_011
    assert Context.CharacterConfigs.get(character.id).key_binds == binds
  end

  test "guide records merge and persist", %{character: character, state: state} do
    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call({:merge_guide_records, %{101 => 2}}, :from, state)

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call({:merge_guide_records, %{202 => 4}}, :from, state)

    assert state.config.guide_records == %{101 => 2, 202 => 4}
    assert Context.CharacterConfigs.get(character.id).guide_records == %{101 => 2, 202 => 4}
  end
end
