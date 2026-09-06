defmodule Ms2ex.Repo.Migrations.AddFishAlbumToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :fish_album, :binary, null: true
      add :discovered_objects, {:array, :integer}, default: []
    end
  end
end
