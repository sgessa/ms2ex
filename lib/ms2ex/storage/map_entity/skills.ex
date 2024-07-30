defmodule Ms2ex.Storage.MapEntity.Skills do
  alias Ms2ex.Metadata
  alias Ms2ex.Enums

  def get_region(field_id, skill_id) do
    Metadata.MapEntity
    |> Metadata.filter("#{x_block(field_id)}_*")
    |> Enum.find(fn region ->
      region.block[:!] == Enums.MapEntity.get_value(:region_skill) &&
        Map.get(region.block, :skill_id) == skill_id
    end)
  end

  defp x_block(field_id),
    do: Metadata.get(Metadata.Map, field_id).x_block
end
