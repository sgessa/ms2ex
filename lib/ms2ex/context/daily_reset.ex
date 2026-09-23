defmodule Ms2ex.Context.DailyReset do
  @moduledoc """
  Resets per-character daily state when the midnight worker fires.

  The single `reset/0` entry point bulk-zeroes the persisted daily columns for
  every character, then clears the in-memory state and refreshes the client
  gauge for each connected player. Add new daily fields and their refresh
  packets here as they appear.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ms2ex.Net.SenderSession, only: [push: 2]

  # zeroes the harvest counters (which drive the harvest success rate) and the
  # daily instant-revive allowance for every character, then clears in-memory
  # state and refreshes the client gauge for connected players
  def reset do
    Schema.CharacterConfig
    |> Repo.update_all(set: [gathering_counts: %{}, instant_revive_count: 0])

    Context.PremiumMemberships.reset_claimed()

    Managers.Character.online_ids()
    |> Enum.each(fn character_id ->
      Managers.CharacterConfig.reset_daily(character_id)
      notify(character_id)
    end)
  end

  # the reset sweeps every live character, including ones whose session
  # already went away
  defp notify(character_id) do
    case Managers.Character.call(character_id, :lookup) do
      {:ok, %{sender_session_pid: nil}} -> :ok
      {:ok, character} ->
        push(character, Packets.RevivalCount.bytes(0))
        push(character, Packets.UserEnv.gathering_counts(%{}))

      _ ->
        :ok
    end
  end
end
