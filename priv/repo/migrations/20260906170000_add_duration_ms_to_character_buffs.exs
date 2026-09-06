defmodule Ms2ex.Repo.Migrations.AddDurationMsToCharacterBuffs do
  use Ecto.Migration

  def change do
    alter table(:character_buffs) do
      add :duration_ms, :integer
    end
  end
end
