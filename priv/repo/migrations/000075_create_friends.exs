defmodule Ms2ex.Repo.Migrations.CreateFriends do
  use Ecto.Migration

  def change do
    create table(:friends) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :rcpt_id, references(:characters, on_delete: :delete_all), null: false

      add :block_reason, :string
      add :is_request, :boolean
      add :message, :string
      add :shared_id, :bigint
      add :status, :integer, null: false

      timestamps(type: :timestamptz)
    end

    create index(:friends, [:character_id])
    create index(:friends, [:rcpt_id])
    create unique_index(:friends, [:character_id, :rcpt_id])
  end
end
