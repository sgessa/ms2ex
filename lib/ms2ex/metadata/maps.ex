defmodule Ms2ex.Metadata.MapNpc do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:id, :coord, :rotation]

  field :id, 1, type: :int32
  field :coord, 2, type: Ms2ex.Metadata.Coord
  field :rotation, 3, type: Ms2ex.Metadata.Coord
end

defmodule Ms2ex.Metadata.MapObject do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:coord, :weapon_id]

  field :coord, 1, type: Ms2ex.Metadata.Coord
  field :weapon_id, 2, type: :int32
end

defmodule Ms2ex.Metadata.MapPortal do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @flags [none: 0, visible: 1, enabled: 2, minimap_visible: 4]

  defstruct [:id, :flags, :target, :coord, :rotation]

  field :id, 1, type: :int32
  field :flags, 2, type: :int32
  field :target, 3, type: :int32
  field :coord, 4, type: Ms2ex.Metadata.Coord
  field :rotation, 5, type: Ms2ex.Metadata.Coord

  def has_flag?(portal, flag) do
    flag_value = Keyword.get(@flags, flag)
    Bitwise.band(portal.flags, flag_value) != 0
  end
end

defmodule Ms2ex.Metadata.MapSpawn do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:coord, :rotation]

  field :coord, 1, type: Ms2ex.Metadata.Coord
  field :rotation, 2, type: Ms2ex.Metadata.Coord
end

defmodule Ms2ex.Metadata.Map do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:id, :npcs, :portals, :spawns, :objects, :bounding_box_0, :bounding_box_1]

  field :id, 1, type: :int32
  field :npcs, 2, repeated: true, type: Ms2ex.Metadata.MapNpc
  field :portals, 3, repeated: true, type: Ms2ex.Metadata.MapPortal
  field :spawns, 4, repeated: true, type: Ms2ex.Metadata.MapSpawn
  field :objects, 5, repeated: true, type: Ms2ex.Metadata.MapObject
  field :bounding_box_0, 6, type: Ms2ex.Metadata.Coord
  field :bounding_box_1, 7, type: Ms2ex.Metadata.Coord
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

    for %{id: map_id} = metadata <- list.items do
      :ets.insert(@table, {map_id, metadata})
    end
  end

  def lookup(map_id) do
    case :ets.lookup(@table, map_id) do
      [{_id, %Map{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
