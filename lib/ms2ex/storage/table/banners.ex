defmodule Ms2ex.Storage.Tables.Banners do
  alias Ms2ex.Storage

  @table_name "banner.xml"

  def get(banner_id) do
    Storage.get(:table, @table_name)
    |> get_in([:table, :entries, to_string(banner_id)])
  end

  def for_map(map_id) do
    Storage.get(:table, @table_name)
    |> get_in([:table, :entries])
    |> case do
      entries when is_map(entries) ->
        entries
        |> Map.values()
        |> Enum.filter(&(&1.map_id == map_id))

      _ ->
        []
    end
  end
end
