defmodule Ms2ex.Storage.Tables.GachaInfo do
  alias Ms2ex.Storage

  def get(id) when is_integer(id) do
    Storage.get(:table, "gacha_info.xml")
    |> get_in([:table, :entries, to_string(id)])
  end

  def get(_id), do: nil
end
