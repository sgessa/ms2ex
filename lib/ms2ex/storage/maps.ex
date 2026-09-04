defmodule Ms2ex.Storage.Maps do
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  @field_spawn_height 25

  def get_bounds(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:boundings)
    |> hd()
    |> then(&Map.put(&1, :position1, struct(Coord, &1.position1)))
    |> then(&Map.put(&1, :position2, struct(Coord, &1.position2)))
  end

  @doc """
  One of the map's enabled spawn points, picked at random. Respawns use it
  directly (the player is placed on the exact coordinate); field entry
  builds on it (see `get_field_spawn/1`) so the player drops in from above.
  """
  def get_spawn(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:pc_spawns)
    |> Enum.filter(& &1.enable)
    |> Enum.map(fn spawn ->
      position = Map.get(spawn, :position, %{})
      rotation = Map.get(spawn, :rotation, %{})

      spawn
      |> Map.put(:position, struct(Coord, position))
      |> Map.put(:rotation, struct(Coord, rotation))
    end)
    |> Enum.random()
  end

  @doc """
  Spawn point to drop a player onto when they enter a field. Entering flush
  with the floor drops the player through it, so the arrival sits above the
  spawn point and falls the short distance.
  """
  @spec get_field_spawn(integer()) :: map()
  def get_field_spawn(map_id) do
    spawn_point = get_spawn(map_id)
    position = spawn_point.position

    %{spawn_point | position: %{position | z: position.z + @field_spawn_height}}
  end

  def get_npc_spawns(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:npc_spawns)
  end

  def get_mob_spawns(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:mob_spawns)
  end

  def get_mob_gates(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:mob_gates, [])
    |> Map.new(fn gate -> {gate.spawn_point_id, gate} end)
  end

  def get_interact_objects(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:interact_objects, [])
    |> Enum.map(fn object ->
      object
      |> Map.put(:position, struct(Coord, Map.get(object, :position, %{})))
      |> Map.put(:rotation, struct(Coord, Map.get(object, :rotation, %{})))
    end)
  end

  def get_portals(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:portals)
    |> Enum.filter(& &1[:enable])
    |> Enum.map(fn portal ->
      position = Map.get(portal, :position, %{})
      rotation = Map.get(portal, :rotation, %{})

      portal
      |> Map.put(:enable, Map.get(portal, :enable, false))
      |> Map.put(:visible, Map.get(portal, :visible, false))
      |> Map.put(:minimap_visible, Map.get(portal, :minimap_visible, false))
      |> Map.put(:position, struct(Coord, position))
      |> Map.put(:rotation, struct(Coord, rotation))
    end)
  end

  def get_meta(map_id) do
    Storage.get(:map, map_id)
  end

  # the map's property flags, including the revival/return rules projected by
  # the ingest (revival_return_id, no_revival_here, only_dark_tomb, ...)
  def get_property(map_id) do
    map_id
    |> get_meta()
    |> case do
      nil -> %{}
      meta -> Map.get(meta, :property, %{})
    end
  end

  def get_revival_return_id(map_id) do
    Map.get(get_property(map_id), :revival_return_id, 0) || 0
  end
end
