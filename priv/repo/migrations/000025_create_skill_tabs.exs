defmodule Ms2ex.Repo.Migrations.CreateSkillTabs do
  use Ecto.Migration

  def change do
    create table(:skill_tabs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :tab_id, :integer, null: false
    end

    create index(:skill_tabs, [:character_id])

    alter table(:characters) do
      add :active_skill_tab_id, :integer
    end
  end
end
