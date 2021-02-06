defmodule Ms2ex.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      add :event_merets, :integer, null: false
      add :game_merets, :integer, null: false
      add :havi_fruits, :integer, null: false
      add :merets, :integer, null: false
      add :mesos, :integer, null: false
      add :meso_tokens, :integer, null: false
      add :rues, :integer, null: false
      add :trevas, :integer, null: false
      add :valor_tokens, :integer, null: false
    end

    create unique_index(:wallets, [:character_id])

    create(constraint(:wallets, :balance_non_negative,
      check: "event_merets >= 0 and game_merets >= 0 and havi_fruits >= 0 and " <>
        "merets >= 0 and mesos >= 0 and meso_tokens >= 0 and rues >= 0 and valor_tokens >= 0")
    )
  end
end
