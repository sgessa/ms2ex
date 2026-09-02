defmodule Ms2ex.Repo.Migrations.AddRevivalStateToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      # death penalty: the count of consecutive deaths and the tick the
      # penalty ends; both persist so a restart does not wipe them mid-day
      add :death_count, :integer, default: 0
      add :death_tick, :bigint, default: 0
      # daily meso instant-revive allowance; the counter is reset to 0 by the
      # scheduled daily-reset worker (Oban crontab), not on server restart
      add :instant_revive_count, :integer, default: 0
    end
  end
end
