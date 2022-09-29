defmodule Ms2ex.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      add :havi_fruits, :integer, null: false
      add :mesos, :integer, null: false
      add :rues, :integer, null: false
      add :trevas, :integer, null: false
      add :valor_tokens, :integer, null: false
    end

    create unique_index(:wallets, [:character_id])

    create(
      constraint(:wallets, :balance_non_negative,
        check:
          "havi_fruits >= 0 and mesos >= 0 and rues >= 0 and trevas >= 0 and valor_tokens >= 0"
      )
    )
  end
end
