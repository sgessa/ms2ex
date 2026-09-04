defmodule Ms2ex.Repo.Migrations.AddBannerSlotWindows do
  use Ecto.Migration

  def change do
    alter table(:banner_slots) do
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
    end

    drop_if_exists unique_index(:banner_slots, [:banner_id, :date, :hour])

    create unique_index(:banner_slots, [:banner_id, :date, :hour],
             where: "starts_at IS NULL",
             name: :banner_slots_hourly_reservation_index
           )

    create unique_index(:banner_slots, [:banner_id, :starts_at],
             where: "starts_at IS NOT NULL",
             name: :banner_slots_window_reservation_index
           )
  end
end
