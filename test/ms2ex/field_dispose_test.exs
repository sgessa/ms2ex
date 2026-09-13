defmodule Ms2ex.FieldDisposeTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers.Field

  defp shared_state do
    %{sessions: %{}, instance: 0, dispose_timer: nil, map_id: 2_000_000, channel_id: 1}
  end

  defp instanced_state do
    %{sessions: %{}, instance: 3, dispose_timer: nil, map_id: 52_000_101, channel_id: 1}
  end

  test "an empty shared field arms the dispose timer" do
    assert {:noreply, state} = Field.handle_info(:maybe_stop, shared_state())
    assert is_reference(state.dispose_timer)
  end

  test "the dispose timer fires only while the field is still empty" do
    state = %{shared_state() | dispose_timer: Process.send_after(self(), :noop, 50_000)}

    assert {:stop, :normal, _} = Field.handle_info(:dispose_if_empty, state)

    # a player joined before the timer fired: keep the field, drop the timer
    state = %{shared_state() | dispose_timer: Process.send_after(self(), :noop, 50_000)}
    state = %{state | sessions: %{1 => self()}}

    assert {:noreply, %{dispose_timer: nil}} = Field.handle_info(:dispose_if_empty, state)
  end

  test "re-arming replaces the pending timer" do
    state = Field.handle_info(:maybe_stop, shared_state()) |> elem(1)
    first_timer = state.dispose_timer

    assert {:noreply, state} = Field.handle_info(:maybe_stop, state)
    assert is_reference(state.dispose_timer)
    assert state.dispose_timer != first_timer
  end

  test "an empty instanced field stops immediately" do
    assert {:stop, :normal, _} = Field.handle_info(:maybe_stop, instanced_state())
  end

  test "a leave while other players remain does not arm anything" do
    state = %{shared_state() | sessions: %{1 => self(), 2 => self()}}

    assert {:noreply, %{dispose_timer: nil}} = Field.handle_info(:maybe_stop, state)
  end
end
