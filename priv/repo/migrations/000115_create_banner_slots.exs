defmodule Ms2ex.Repo.Migrations.CreateBannerSlots do
  use Ecto.Migration

  def change do
    create table(:banner_slots) do
      add :banner_id, :bigint, null: false
      add :date, :integer, null: false
      add :hour, :integer, null: false
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :ugc_resource_id, references(:ugc_resources, on_delete: :nilify_all)

      timestamps(type: :timestamptz)
    end

    create unique_index(:banner_slots, [:banner_id, :date, :hour])
  end
end
