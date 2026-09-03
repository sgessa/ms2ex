defmodule Ms2ex.Repo.Migrations.CreateUgcResources do
  use Ecto.Migration

  def change do
    create table(:ugc_resources) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      add :path, :string, null: false, default: ""
      add :type, :integer, null: false

      timestamps(type: :timestamptz)
    end

    create index(:ugc_resources, [:character_id])
  end
end
