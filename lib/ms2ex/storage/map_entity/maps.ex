defmodule Ms2ex.Storage.MapEntity.Maps do
  alias Ms2ex.Metadata
  alias Ms2ex.Enums

  def get_bounds(field_id) do
    Metadata.MapEntity
    |> Metadata.filter("#{x_block(field_id)}_*")
    |> Enum.filter(&(&1.block[:!] == Enums.MapEntity.get_value(:bounds)))
    |> hd()
  end

  defp x_block(field_id),
    do: Metadata.get(Metadata.Map, field_id).x_block
end
