defmodule Ms2ex.Storage.Maps do
  alias Ms2ex.Storage

  def get_bounds(field_id) do
    field_id
    |> get_meta()
    |> Map.get(:boundings)
    |> hd()
    |> Map.get(:block)
  end

  def get_spawn(field_id) do
    field_id
    |> get_meta()
    |> Map.get(:pc_spawns)
    |> Enum.filter(&Map.get(&1.block, :enable))
    |> Enum.random()
    |> Map.get(:block)
  end

  def get_npcs(field_id) do
    field_id
    |> get_meta()
    |> Map.get(:npcs)
    |> Enum.filter(&(&1.type == :npc))
    |> Enum.filter(& &1.spawn.visible)
    |> Enum.reject(&is_nil(&1.metadata))
  end

  def get_meta(field_id) do
    Storage.get(:map, field_id)
  end
end
