defmodule Ms2ex.Repo.Migrations.CreateAccountWallets do
  use Ecto.Migration

  def change do
    create table(:account_wallets) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      add :event_merets, :integer, null: false
      add :game_merets, :integer, null: false
      add :merets, :integer, null: false
      add :meso_tokens, :integer, null: false
    end

    create unique_index(:account_wallets, [:account_id])

    create(
      constraint(:account_wallets, :balance_non_negative,
        check: "event_merets >= 0 and game_merets >= 0 and merets >= 0 and meso_tokens >= 0"
      )
    )
  end
end
