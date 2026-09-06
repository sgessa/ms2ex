defmodule Ms2ex.Repo.Migrations.CreateMails do
  use Ecto.Migration

  def change do
    create table(:mails) do
      add :sender_id, :bigint, null: false, default: 0
      add :sender_name, :string, null: false, default: ""
      add :receiver_id, :bigint, null: false
      add :receiver_type, :integer, null: false, default: 0
      add :type, :integer, null: false, default: 1

      add :title, :string, null: false, default: ""
      add :content, :text, null: false, default: ""
      add :title_args, :binary
      add :content_args, :binary
      add :wedding_invite, :string, null: false, default: ""

      add :mesos, :bigint, null: false, default: 0
      add :mesos_collected_at, :timestamptz
      add :merets, :bigint, null: false, default: 0
      add :merets_collected_at, :timestamptz
      add :game_merets, :bigint, null: false, default: 0
      add :game_merets_collected_at, :timestamptz

      add :read_at, :timestamptz
      add :expires_at, :timestamptz, null: false

      timestamps(type: :timestamptz)
    end

    create index(:mails, [:receiver_id, :receiver_type])
    create index(:mails, [:sender_id])
    create index(:mails, [:expires_at])

    alter table(:inventory_items) do
      modify :character_id, :bigint, null: true
      add :mail_id, references(:mails, on_delete: :delete_all)
    end

    create index(:inventory_items, [:mail_id])
  end
end
