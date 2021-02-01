defmodule Ms2ex.Repo.Migrations.CreateSkillTabs do
  use Ecto.Migration

  def change do
    create table(:skill_tabs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :name, :string, null: false
    end

    create index(:skill_tabs, [:character_id])
  end
end
