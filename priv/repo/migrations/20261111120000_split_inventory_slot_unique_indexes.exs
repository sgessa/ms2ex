defmodule Ms2ex.Repo.Migrations.SplitInventorySlotUniqueIndexes do
  use Ecto.Migration

  # pet bag rows (location 3) live per-owner-item and must not collide with
  # the inventory's slot key-space: the single table-wide unique index made
  # a bag slot and an inventory slot mutually exclusive. Each location
  # keeps its own uniqueness instead.
  def change do
    drop_if_exists unique_index(:inventory_items, [:character_id, :inventory_slot, :inventory_tab])

    create unique_index(:inventory_items, [:character_id, :inventory_tab, :inventory_slot],
             where: "location = 0",
             name: :inventory_items_inventory_slot_index
           )

    create unique_index(:inventory_items, [:character_id, :inventory_tab, :inventory_slot],
             where: "location = 1",
             name: :inventory_items_equipment_slot_index
           )

    create unique_index(:inventory_items, [:character_id, :owner_item_id, :inventory_slot],
             where: "location = 3",
             name: :inventory_items_pet_bag_slot_index
           )
  end
end
