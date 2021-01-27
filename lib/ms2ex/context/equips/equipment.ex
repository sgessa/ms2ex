defmodule Ms2ex.Equipment do
  use Ecto.Schema

  import Ecto.Changeset

  schema "equipments" do
    belongs_to :character, Ms2ex.Character

    belongs_to :ears, Ms2ex.Inventory.Item
    belongs_to :face, Ms2ex.Inventory.Item
    belongs_to :face_decor, Ms2ex.Inventory.Item
    belongs_to :hair, Ms2ex.Inventory.Item
    belongs_to :top, Ms2ex.Inventory.Item
    belongs_to :bottom, Ms2ex.Inventory.Item
    belongs_to :shoes, Ms2ex.Inventory.Item
  end

  @doc false
  def changeset(equips, attrs) do
    equips
    |> cast(attrs, [:ears_id, :face_id, :face_decor_id, :hair_id, :top_id, :bottom_id, :shoes_id])
  end
end
