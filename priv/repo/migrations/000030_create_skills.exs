defmodule Ms2ex.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills) do
      add :skill_tab_id, references(:skill_tabs, on_delete: :delete_all), null: false

      add :skill_id, :integer, null: false
      add :level, :integer, null: false
      add :max_level, :integer, null: false
      add :sub_skills, :binary
      add :rank, :integer, null: false
    end

    create index(:skills, [:skill_tab_id])
    create unique_index(:skills, [:skill_tab_id, :skill_id])
  end
end
