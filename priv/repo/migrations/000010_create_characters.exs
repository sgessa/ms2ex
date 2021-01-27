defmodule Ms2ex.Repo.Migrations.CreateCharacters do
  use Ecto.Migration

  def change do
    create table(:characters) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      add :awakened, :boolean, null: false
      add :exp, :bigint, null: false
      add :gender, :integer, null: false
      add :level, :integer, null: false
      add :job, :integer, null: false
      add :map_id, :integer, null: false
      add :motto, :string, null: false
      add :name, :citext, null: false
      add :position, :binary, null: false
      add :prestige_exp, :bigint
      add :prestige_level, :integer
      add :profile_url, :string
      add :rest_exp, :bigint, null: false
      add :rotation, :binary, null: false
      add :skin_color, :binary, null: false

      timestamps(type: :timestamptz)
    end

    create index(:characters, [:account_id])
    create unique_index(:characters, [:name])
  end
end
