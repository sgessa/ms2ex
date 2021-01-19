defmodule Ms2ex.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :username, :string, null: false
      add :password_hash, :string, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:accounts, [:username])
  end
end
