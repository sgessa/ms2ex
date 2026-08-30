defmodule Ms2ex.Workers.DailyReset do
  @moduledoc """
  Runs at midnight (Oban crontab) to reset each character's daily meso
  instant-revive allowance. The counter is stored on the character row so it
  survives restarts; only the day roll-over (this job) clears it. Connected
  players are told immediately so their in-memory counter and the client's
  "uses left" gauge reset too.
  """
  use Oban.Worker

  import Ecto.Query

  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @impl Oban.Worker
  def perform(_job) do
    from(c in Schema.Character, where: c.instant_revive_count > 0)
    |> Repo.update_all(set: [instant_revive_count: 0])

    connected_character_ids()
    |> Enum.each(&Managers.Character.cast(&1, :reset_daily_revives))

    :ok
  end

  # character managers are registered under :"characters:#{id}" in the local
  # registry; enumerate those names to reach every online player
  defp connected_character_ids do
    :erlang.registered()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(&String.starts_with?(&1, "characters:"))
    |> Enum.map(&String.trim_leading(&1, "characters:"))
    |> Enum.map(&String.to_integer/1)
  end
end
