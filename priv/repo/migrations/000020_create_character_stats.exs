defmodule Ms2ex.Repo.Migrations.CreateCharacterStats do
  use Ecto.Migration

  def change do
    create table(:character_stats) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      Enum.each(Ms2ex.Schema.CharacterStats.fields(), fn field ->
        add field, :integer, null: false
      end)
    end

    create unique_index(:character_stats, [:character_id])
  end
end
