defmodule Ms2ex.Storage.Tables.Instruments do
  alias Ms2ex.Storage

  @type metadata :: %{
          id: integer(),
          equip_id: integer(),
          score_count: integer(),
          category: integer(),
          midi_id: integer(),
          percussion_id: integer()
        }

  @spec lookup(pos_integer()) :: {:ok, metadata()} | :error
  def lookup(instrument_id) do
    :table
    |> Storage.get("instrumentcategoryinfo.xml")
    |> get_in([:table, :entries, to_string(instrument_id)])
    |> case do
      nil -> :error
      instrument -> {:ok, instrument}
    end
  end
end
