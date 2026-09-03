defmodule Ms2ex.Repo.Migrations.CreateAchievements do
  use Ecto.Migration

  def change do
    create table(:achievements, primary_key: false) do
      add :owner_id, :bigint, primary_key: true
      add :achievement_id, :integer, primary_key: true
      add :current_grade, :integer, null: false
      add :reward_grade, :integer, null: false
      add :favorite, :boolean, null: false, default: false
      add :counter, :bigint, null: false, default: 0
      add :category, :integer, null: false
      add :grades, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:achievements, [:owner_id])
  end
end
