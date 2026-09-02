defmodule Ms2ex.Workers.DailyReset do
  @moduledoc """
  Runs at midnight (Oban crontab) to reset each character's daily meso
  instant-revive allowance. The counter is stored on the character row so it
  survives restarts; only the day roll-over (this job) clears it. Connected
  players are told immediately so their in-memory counter and the client's
  "uses left" gauge reset too.
  """
  use Oban.Worker

  alias Ms2ex.Context

  @impl Oban.Worker
  def perform(_job) do
    Context.DailyReset.reset()
  end
end
