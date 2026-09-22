defmodule Ms2ex.BattleStanceTest do
  # the stance deadline is a pure field-state transition: the window is
  # shortened through the server constants stub and the leave broadcast is
  # captured through the field-character module
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field
  alias Ms2ex.Managers.Field.Trigger.Actions
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

  test "arming schedules the drop check after the quiet window" do
    state = %{}

    state = Field.arm_battle_stance(state, character())

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

    state = Field.arm_battle_stance(%{}, character())

    # a newer cast re-stamps the deadline before the old one expired
    :timer.sleep(20)
    state = Field.arm_battle_stance(state, character())

    # the fired check from the stale deadline reschedules instead of leaving
    assert_receive {:battle_stance_drop, 77}, 500

    assert {stay_or_leave, _state} = Field.battle_stance_drop(state, 77)
    assert stay_or_leave == :stay
    refute_received {:left_battle, 77}

    # once the refreshed window passes without another cast, the stance drops
    state = put_in(state, [:battle_stances, 77, :cast_at], Ms2ex.sync_ticks() - 200)
    assert {:leave, state} = Field.battle_stance_drop(state, 77)

    assert_receive {:left_battle, 77}
    refute Map.has_key?(state.battle_stances, 77)
  end

  test "dropping an unknown character is a no-op" do
    assert {:stay, %{}} = Field.battle_stance_drop(%{}, 77)
  end
end
