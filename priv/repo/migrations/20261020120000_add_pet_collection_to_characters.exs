defmodule Ms2ex.Repo.Migrations.AddPetCollectionToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :pet_collection, :binary, null: true
    end
  end
end
