defmodule Ms2ex.Repo.Migrations.RemoveReturnMapIdFromCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      remove :return_map_id
    end
  end
end
