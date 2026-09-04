defmodule Ms2ex.Repo.Migrations.AddGuideRecordsToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :guide_records, :binary, null: true
    end
  end
end
