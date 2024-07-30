defmodule Ms2ex.ProtoMetadata.MapEntity do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :npcs, 2, repeated: true, type: Ms2ex.ProtoMetadata.MapNpc
  field :portals, 3, repeated: true, type: Ms2ex.ProtoMetadata.MapPortal
  field :character_spawns, 4, repeated: true, type: Ms2ex.ProtoMetadata.CharacterSpawn
  field :mob_spawns, 5, repeated: true, type: Ms2ex.ProtoMetadata.MobSpawn
  field :objects, 6, repeated: true, type: Ms2ex.ProtoMetadata.MapObject
  field :bounding_box_0, 7, type: Ms2ex.Metadata.Coord
  field :bounding_box_1, 8, type: Ms2ex.Metadata.Coord

  # field :healing_spots, 9, repeated: true, type: Ms2ex.ProtoMetadata.HealingSpot
  # field :patrol_data, 10, repeated: true, type: Ms2ex.ProtoMetadata.PatrolData
  # field :way_points, 11, repeated: true, type: Ms2ex.ProtoMetadata.WayPoint
  # field :trigger_meshes, 12, repeated: true, type: Ms2ex.ProtoMetadata.TriggerMesh
  # field :trigger_effects, 13, repeated: true, type: Ms2ex.ProtoMetadata.TriggerEffect
  # field :trigger_cameras, 14, repeated: true, type: Ms2ex.ProtoMetadata.TriggerCamera
  # field :trigger_boxes, 15, repeated: true, type: Ms2ex.ProtoMetadata.TriggerBox
  # field :trigger_ladders, 16, repeated: true, type: Ms2ex.ProtoMetadata.TriggerLadder
  # field :event_npc_spawns, 17, repeated: true, type: Ms2ex.ProtoMetadata.EventNpcSpawn
  # field :trigger_actors, 18, repeated: true, type: Ms2ex.ProtoMetadata.TriggerActor
  # field :trigger_cubes, 19, repeated: true, type: Ms2ex.ProtoMetadata.TriggerCube
  # field :trigger_sounds, 20, repeated: true, type: Ms2ex.ProtoMetadata.TriggerSound
  # field :trigger_ropes, 21, repeated: true, type: Ms2ex.ProtoMetadata.TriggerRope
  # field :breakable_actors, 22, repeated: true, type: Ms2ex.ProtoMetadata.BreakableActor
  # field :breakable_nifs, 23, repeated: true, type: Ms2ex.ProtoMetadata.BreakableNif
  # field :vibrate_objects, 24, repeated: true, type: Ms2ex.ProtoMetadata.VibrateObject

  field :interactable_objects, 25, repeated: true, type: Ms2ex.ProtoMetadata.InteractableObject
end

defmodule Ms2ex.ProtoMetadata.MapEntities do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.MapEntity

  field :items, 1, repeated: true, type: MapEntity

  @table :map_entity_metadata

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
      [{_id, %MapEntity{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
