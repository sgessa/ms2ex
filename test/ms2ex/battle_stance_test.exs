defmodule Ms2ex.BattleStanceTest do
  # the stance lifecycle is driven through the field's callbacks on a plain
  # state map: the window is shortened via the server constants stub and the
  # sheathe broadcast is captured through the field-character module
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "table:server.constants.xml" => %{user_battle_duration_tick: 100}
    })

    :ok
  end

  defp character do
    %Schema.Character{id: 77, object_id: 5, field_pid: nil, sender_session_pid: nil}
  end

  test "entering battle arms the stance and schedules the drop check" do
    {:noreply, state} = Field.handle_cast({:enter_battle_stance, character()}, %{})

    entry = state.battle_stances[77]
    assert entry.cast_at <= Ms2ex.sync_ticks()
    assert entry.timer != nil

    # the quiet window closes: the drop check fires once
    assert_receive {:battle_stance_drop, 77}, 500
  end

  test "re-arming refreshes the deadline so the stance survives the old window" do
    Mimic.stub(Ms2ex.Managers.Field.Character, :leave_battle_stance, fn character ->
      send(self(), {:left_battle, character.id})
      :ok
    end)

    {:noreply, state} = Field.handle_cast({:enter_battle_stance, character()}, %{})

    # a newer cast re-stamps the deadline before the old one expired
    :timer.sleep(20)
    {:noreply, state} = Field.handle_cast({:enter_battle_stance, character()}, state)

    # a stale check firing while a newer cast already re-stamped the
    # deadline reschedules itself instead of leaving
    state = put_in(state, [:battle_stances, 77, :cast_at], Ms2ex.sync_ticks() - 60)
    {:noreply, state} = Field.handle_info({:battle_stance_drop, 77}, state)

    refute_received {:left_battle, 77}

    # once the refreshed window passes without another cast, the stance drops
    assert_receive {:battle_stance_drop, 77}, 500
    state = put_in(state, [:battle_stances, 77, :cast_at], Ms2ex.sync_ticks() - 200)
    {:noreply, state} = Field.handle_info({:battle_stance_drop, 77}, state)

    assert_receive {:left_battle, 77}
    refute Map.has_key?(state.battle_stances, 77)
  end

  test "dropping an unknown character is a no-op" do
    assert {:noreply, %{}} = Field.handle_info({:battle_stance_drop, 77}, %{})
  end
end
