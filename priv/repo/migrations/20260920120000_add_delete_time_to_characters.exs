defmodule Ms2ex.Repo.Migrations.AddDeleteTimeToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :delete_time, :bigint, null: false, default: 0
    end
  end
end
