defmodule Ms2ex.Navigation do
  @moduledoc """
  Navmesh queries for a map: position validity, floor snapping and
  pathfinding. Navmesh coordinates are meters with Y up, so map positions
  transform by a -90 degree rotation about X and a 1/100 scale.

  Queries run on the native Detour runtime over the full mesh binary the
  ingest ships (the `navmesh_bin` set) — the same library lineage the
  meshes are built with. Meshes load lazily once per map and are cached
  for the node's lifetime; maps without a binary mesh have no walkable
  ground.
  """

  alias Ms2ex.Navigation.Native
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  @doc """
  A corridor of walkable points from `from` to `to`, or `:error` when
  either endpoint has no walkable ground or no connection exists between
  them. Intermediate points are the string-pulled bends of the polygon
  corridor, carrying the mesh surface heights at each bend.
  """
  @spec find_path(integer(), Coord.t(), Coord.t()) :: {:ok, [Coord.t()]} | :error
  def find_path(map_id, %Coord{} = from, %Coord{} = to) when is_integer(map_id) do
    case native_mesh(map_id) do
      nil ->
        :error

      mesh ->
        case Native.find_path(mesh, to_nav(from), to_nav(to)) do
          {:ok, path} -> {:ok, Enum.map(path, &to_coord/1)}
          {:error, _reason} -> :error
        end
    end
  end

  def find_path(_, _, _), do: :error

  @doc """
  Whether a position stands on walkable ground. Maps without a navmesh
  accept every position.
  """
  def valid_position?(map_id, %Coord{} = position) when is_integer(map_id) do
    case native_mesh(map_id) do
      nil -> true
      mesh -> Native.valid_position(mesh, to_nav(position))
    end
  end

  def valid_position?(_, _), do: true

  @doc """
  The closest walkable point to a position, or nil when the map has no
  navmesh (or nothing walkable within the query box). Movement snaps npc
  positions to this point every step — pathed movement rides the ground
  surface instead of the straight line between waypoints, which cuts below
  it on slopes and stairs.
  """
  def snap_to_floor(map_id, %Coord{} = position) when is_integer(map_id) do
    case native_mesh(map_id) do
      nil ->
        nil

      mesh ->
        case Native.snap(mesh, to_nav(position)) do
          {:ok, point} -> to_coord(point)
          {:error, _reason} -> nil
        end
    end
  end

  # spawn documents project positions as plain x/y/z maps
  def snap_to_floor(map_id, %{x: _, y: _, z: _} = position) when is_integer(map_id) do
    snap_to_floor(map_id, struct(Coord, Map.to_list(position)))
  end

  def snap_to_floor(_, _position), do: nil

  @doc "Whether the map has walkable navmesh tiles."
  def has_navmesh?(map_id) when is_integer(map_id), do: native_mesh(map_id) != nil
  def has_navmesh?(_), do: false

  # -- mesh cache ---------------------------------------------------------------

  # the loaded Detour mesh for a map, or nil when the map carries no
  # binary mesh. meshes are immutable once loaded and cached per xblock;
  # missing meshes are negatively cached
  defp native_mesh(map_id) do
    case Storage.Maps.get_meta(map_id) do
      %{x_block: xblock} -> native_mesh_for(xblock)
      _ -> nil
    end
  end

  defp native_mesh_for(xblock) do
    case :persistent_term.get({:navmesh_native, xblock}, :missing) do
      :missing ->
        mesh =
          case Storage.get_raw("navmesh_bin", xblock) do
            bytes when is_binary(bytes) -> Native.load_mesh(bytes)
            _ -> nil
          end

        :persistent_term.put({:navmesh_native, xblock}, mesh)
        mesh

      cached ->
        cached
    end
  end

  # -- coordinate conversion -----------------------------------------------------

  # MS2 is Z-up; the navmesh is meters with Y up
  defp to_nav(%Coord{x: x, y: y, z: z}), do: {x / 100, z / 100, -y / 100}

  defp to_coord({cx, cy, cz}), do: %Coord{x: cx * 100, y: -cz * 100, z: cy * 100}
end
