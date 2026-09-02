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

  import Ecto.Query, except: [update: 2]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  # zeroes every character's daily meso instant-revive allowance, then resets
  # in-memory state and refreshes the client gauge for connected players
  def reset do
    from(c in Schema.Character)
    |> Repo.update_all(set: [instant_revive_count: 0])

    Managers.Character.online_ids()
    |> Enum.each(&Managers.Character.cast(&1, :daily_reset))
  end

  # clears one connected player's in-memory daily fields and refreshes the
  # client gauge; runs in the character manager via the :daily_reset cast
  def reset_character(character) do
    character = Map.put(character, :instant_revive_count, 0)
    push(character, Packets.RevivalCount.bytes(0))
    character
  end
end
