defmodule Ms2ex.Context.DailyReset do
  @moduledoc """
  Resets per-character daily state when the midnight worker fires.

  The single `reset/0` entry point bulk-zeroes the persisted daily columns for
  every character, then clears the in-memory state and refreshes the client
  gauge for each connected player. `reset_character/1` is the per-player step,
  invoked by the character manager's cast so the in-memory character stays in
  sync. Add new daily fields and their refresh packets here as they appear.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ms2ex.Net.SenderSession, only: [push: 2]

  # zeroes every character's daily meso instant-revive allowance and gathering
  # counts (which drive the harvest success rate), then resets in-memory state
  # and refreshes the client for connected players
  def reset do
    Schema.Character
    |> Repo.update_all(set: [instant_revive_count: 0, gathering_counts: nil])

    Managers.Character.online_ids()
    |> Enum.each(&Managers.Character.cast(&1, :daily_reset))
  end

  # clears one connected player's in-memory daily fields and refreshes the
  # client gauge; runs in the character manager via the :daily_reset cast
  def reset_character(character) do
    character =
      character
      |> Map.put(:instant_revive_count, 0)
      |> Map.put(:gathering_counts, %{})

    notify(character)
    character
  end

  # the reset sweeps every live character process, including ones whose
  # session already went away
  defp notify(%{sender_session_pid: nil}), do: :ok

  defp notify(character) do
    push(character, Packets.RevivalCount.bytes(0))
    push(character, Packets.UserEnv.gathering_counts(%{}))
  end
end
