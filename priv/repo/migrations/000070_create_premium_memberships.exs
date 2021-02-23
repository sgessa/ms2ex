defmodule Ms2ex.Repo.Migrations.CreatePremiumMemberships do
  use Ecto.Migration

  def change do
    create table(:premium_memberships) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :expires_at, :timestamptz, null: false

      timestamps(type: :timestamptz)
    end

    create index(:premium_memberships, [:account_id])
  end
end
