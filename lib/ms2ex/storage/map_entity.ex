defmodule Ms2ex.Storage.MapEntity do
  alias Ms2ex.Metadata
  alias Ms2ex.Enums

  def get_entities_by_type(field_id, type) do
    Metadata.MapEntity
    |> Metadata.filter("#{get_x_block(field_id)}_*")
    |> Enum.filter(&(&1.block[:!] == Enums.MapEntity.get_value(type)))
  end

  defp get_x_block(field_id),
    do: Metadata.get(Metadata.Map, field_id).x_block
end
