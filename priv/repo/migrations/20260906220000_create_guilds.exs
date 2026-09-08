defmodule Ms2ex.Repo.Migrations.CreateGuilds do
  use Ecto.Migration

  def change do
    create table(:guilds) do
      add :name, :string, null: false
      add :emblem, :string, null: false, default: ""
      add :notice, :text, null: false, default: ""
      add :focus, :integer, null: false, default: 0
      add :experience, :integer, null: false, default: 0
      add :funds, :bigint, null: false, default: 0
      add :house_rank, :integer, null: false, default: 0
      add :house_theme, :integer, null: false, default: 0
      add :capacity, :integer, null: false, default: 60
      add :leader_id, references(:characters, on_delete: :nilify_all), null: false

      add :ranks, :binary, null: false
      add :buffs, :binary, default: "\\x836a"
      add :posters, :binary, default: "\\x836a"
      add :npcs, :binary, default: "\\x836a"
      add :bank, :binary, default: "\\x836a"

      timestamps(type: :timestamptz)
    end

    create unique_index(:guilds, [:name])
    create index(:guilds, [:leader_id])

    create table(:guild_members, primary_key: false) do
      add :guild_id, references(:guilds, on_delete: :delete_all), primary_key: true
      add :character_id, references(:characters, on_delete: :delete_all), primary_key: true
      add :rank, :integer, null: false, default: 4
      add :message, :string, null: false, default: ""
      add :weekly_contribution, :integer, null: false, default: 0
      add :total_contribution, :integer, null: false, default: 0
      add :daily_donation_count, :integer, null: false, default: 0
      add :checkin_at, :timestamptz
      add :donation_at, :timestamptz

      timestamps(type: :timestamptz)
    end

    create unique_index(:guild_members, [:character_id])
    create index(:guild_members, [:guild_id])

    create table(:guild_applications) do
      add :guild_id, references(:guilds, on_delete: :delete_all), null: false
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:guild_applications, [:guild_id, :character_id])
    create index(:guild_applications, [:character_id])
    create index(:guild_applications, [:guild_id])
  end
end
