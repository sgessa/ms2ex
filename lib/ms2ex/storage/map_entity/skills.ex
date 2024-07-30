defmodule Ms2ex.Storage.MapEntity.Skills do
  alias Ms2ex.Storage.MapEntity

  def get_region(field_id, skill_id) do
    field_id
    |> MapEntity.get_entities_by_type(:region_skill)
    |> Enum.find(fn region ->
      Map.get(region.block, :skill_id) == skill_id
    end)
  end
end
