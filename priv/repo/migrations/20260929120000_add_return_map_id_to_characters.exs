defmodule Ms2ex.Repo.Migrations.AddReturnMapIdToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :return_map_id, :integer, null: false, default: 0
    end
  end
end
