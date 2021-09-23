defmodule Ms2ex.Metadata.Map do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :id,
    :npcs,
    :portals,
    :spawns,
    :objects,
    :bounding_box_0,
    :bounding_box_1,
    :interact_objects,
    :interact_meshes
  ]

  field :id, 1, type: :int32
  field :npcs, 2, repeated: true, type: Ms2ex.Metadata.MapNpc
  field :portals, 3, repeated: true, type: Ms2ex.Metadata.MapPortal
  field :spawns, 4, repeated: true, type: Ms2ex.Metadata.MapSpawn
  field :objects, 5, repeated: true, type: Ms2ex.Metadata.MapObject
  field :bounding_box_0, 6, type: Ms2ex.Metadata.Coord
  field :bounding_box_1, 7, type: Ms2ex.Metadata.Coord
  field :interact_objects, 8, repeated: true, type: Ms2ex.Metadata.MapInteractable
  field :interact_meshes, 9, repeated: true, type: Ms2ex.Metadata.MapInteractable
end

defmodule Ms2ex.Metadata.Maps do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Map

  defstruct [:items]

  field :items, 1, repeated: true, type: Map

  @table :map_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-map-entity-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: field_id} = metadata <- list.items do
      :ets.insert(@table, {field_id, metadata})
    end
  end

  def lookup(field_id) do
    case :ets.lookup(@table, field_id) do
      [{_id, %Map{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
