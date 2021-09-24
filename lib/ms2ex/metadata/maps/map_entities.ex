defmodule Ms2ex.Metadata.MapEntity do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :id,
    :npcs,
    :portals,
    :character_spawns,
    :mob_spawns,
    :objects,
    :bounding_box_0,
    :bounding_box_1,
    :healing_spots,
    :patrol_data,
    :way_points,
    :trigger_meshes,
    :trigger_effects,
    :trigger_cameras,
    :trigger_boxes,
    :trigger_ladders,
    :event_npc_spawns,
    :trigger_actors,
    :trigger_cubes,
    :trigger_sounds,
    :trigger_ropes,
    :breakable_actors,
    :brekable_nifs,
    :vibrate_objects,
    :interactable_objects
  ]

  field :id, 1, type: :int32
  field :npcs, 2, repeated: true, type: Ms2ex.Metadata.MapNpc
  field :portals, 3, repeated: true, type: Ms2ex.Metadata.MapPortal
  field :character_spawns, 4, repeated: true, type: Ms2ex.Metadata.CharacterSpawn
  # field :mob_spawns, 5, repeated: true, type: Ms2ex.Metadata.MobSpawn
  field :objects, 6, repeated: true, type: Ms2ex.Metadata.MapObject
  field :bounding_box_0, 7, type: Ms2ex.Metadata.Coord
  field :bounding_box_1, 8, type: Ms2ex.Metadata.Coord

  # field :healing_spots, 9, repeated: true, type: Ms2ex.Metadata.HealingSpot
  # field :patrol_data, 10, repeated: true, type: Ms2ex.Metadata.PatrolData
  # field :way_points, 11, repeated: true, type: Ms2ex.Metadata.WayPoint
  # field :trigger_meshes, 12, repeated: true, type: Ms2ex.Metadata.TriggerMesh
  # field :trigger_effects, 13, repeated: true, type: Ms2ex.Metadata.TriggerEffect
  # field :trigger_cameras, 14, repeated: true, type: Ms2ex.Metadata.TriggerCamera
  # field :trigger_boxes, 15, repeated: true, type: Ms2ex.Metadata.TriggerBox
  # field :trigger_ladders, 16, repeated: true, type: Ms2ex.Metadata.TriggerLadder
  # field :event_npc_spawns, 17, repeated: true, type: Ms2ex.Metadata.EventNpcSpawn
  # field :trigger_actors, 18, repeated: true, type: Ms2ex.Metadata.TriggerActor
  # field :trigger_cubes, 19, repeated: true, type: Ms2ex.Metadata.TriggerCube
  # field :trigger_sounds, 20, repeated: true, type: Ms2ex.Metadata.TriggerSound
  # field :trigger_ropes, 21, repeated: true, type: Ms2ex.Metadata.TriggerRope
  # field :breakable_actors, 22, repeated: true, type: Ms2ex.Metadata.BreakableActor
  # field :breakable_nifs, 23, repeated: true, type: Ms2ex.Metadata.BreakableNif
  # field :vibrate_objects, 24, repeated: true, type: Ms2ex.Metadata.VibrateObject

  field :interactable_objects, 25, repeated: true, type: Ms2ex.Metadata.InteractableObject
end

defmodule Ms2ex.Metadata.MapEntities do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.MapEntity

  defstruct [:items]

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
