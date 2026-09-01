defmodule Ms2ex.Repo.Migrations.AddStatPointsToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :stat_point_sources, :binary, null: true
      add :stat_point_allocation, :binary, null: true
    end
  end
end
