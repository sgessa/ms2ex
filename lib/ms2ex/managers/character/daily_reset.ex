defmodule Ms2ex.Managers.Character.DailyReset do
  @moduledoc """
  Resets per-character daily state when the midnight worker fires.

  Each reset clears the in-memory field and pushes the packet that refreshes
  the client's gauge. The `Ms2ex.Workers.DailyReset` Oban job bulk-zeroes the
  DB columns for every character, then casts `:reset_daily_revives` to each
  connected character manager so the in-memory state and the client update
  too. Add new daily fields and their refresh packets here as they appear.
  """

  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]

  # zeroes the meso instant-revive allowance for a connected player
  def reset_daily_revives(character) do
    character = Map.put(character, :instant_revive_count, 0)
    push(character, Packets.RevivalCount.bytes(0))
    character
  end
end
