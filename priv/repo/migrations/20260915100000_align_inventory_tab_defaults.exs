defmodule Ms2ex.Repo.Migrations.AlignInventoryTabDefaults do
  use Ecto.Migration

  def up do
    execute "UPDATE inventory_tabs SET slots = 156 WHERE tab = 1 AND slots = 150"
    execute "UPDATE inventory_tabs SET slots = 84 WHERE tab = 7 AND slots = 48"
  end

  def down do
    :ok
  end
end
