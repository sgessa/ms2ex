defmodule Ms2ex.Repo.Migrations.AddMaxCharactersToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :max_characters, :integer, null: false, default: 3
    end
  end
end
