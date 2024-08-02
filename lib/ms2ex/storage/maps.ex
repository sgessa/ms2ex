defmodule Ms2ex.Storage.Maps do
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  def get_bounds(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:boundings)
    |> hd()
    |> then(&Map.put(&1, :position1, struct(Coord, &1.position1)))
    |> then(&Map.put(&1, :position2, struct(Coord, &1.position2)))
  end

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

  def get_npcs(map_id) do
    map_id
    |> get_meta()
    |> Map.get(:npcs)
    |> Enum.filter(
      &(&1.type == :npc &&
          get_in(&1, [:spawn, :visible]) &&
          get_in(&1, [:spawn, :spawn_on_field_create]) &&
          !is_nil(&1.metadata))
    )
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
end
