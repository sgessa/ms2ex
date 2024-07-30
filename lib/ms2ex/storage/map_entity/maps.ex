defmodule Ms2ex.Storage.MapEntity.Maps do
  alias Ms2ex.Storage.MapEntity

  def get_bounds(field_id) do
    field_id
    |> MapEntity.get_entities_by_type(:bounding)
    |> hd()
    |> Map.get(:block)
  end

  def get_spawn(field_id) do
    field_id
    |> MapEntity.get_entities_by_type(:spawn_point_pc)
    |> Enum.filter(fn entity ->
      Map.get(entity.block, :enable)
    end)
    |> Enum.random()
    |> Map.get(:block)
  end
end
