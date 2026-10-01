defmodule Ms2ex.Repo.Migrations.CreateAccountStorages do
  use Ecto.Migration

  def change do
    # shared per-account item storage: stored mesos and the purchased
    # slot expansion
    create table(:account_storages, primary_key: false) do
      add :account_id, references(:accounts, on_delete: :delete_all), primary_key: true
      add :mesos, :bigint, null: false, default: 0
      add :expand, :integer, null: false, default: 0

      timestamps(type: :timestamptz)
    end

    create constraint(:account_storages, :stored_non_negative,
             check: "mesos >= 0 and expand >= 0"
           )

    # storage rows live in inventory_items owned by the account
    alter table(:inventory_items) do
      add :account_id, :bigint
    end

    create index(:inventory_items, [:account_id])
  end
end
