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
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  # zeroes the harvest counters (which drive the harvest success rate), the
  # daily instant-revive allowance and the day-interval shop restock counters
  # for every character, then clears in-memory state and refreshes the client
  # gauge for connected players
  def reset do
    Schema.CharacterConfig
    |> Repo.update_all(set: [gathering_counts: %{}, instant_revive_count: 0])

    Context.PremiumMemberships.reset_claimed()

    weekly? = Date.day_of_week(Date.utc_today()) == 4

    Managers.Character.online_ids()
    |> Enum.each(fn character_id ->
      Managers.Mastery.reset_gathering_counts(character_id)
      Managers.CharacterConfig.reset_daily(character_id)
      Managers.Shop.daily_reset(character_id)

      if weekly? do
        Managers.Shop.weekly_reset(character_id)
      end
    end)
  end
end
