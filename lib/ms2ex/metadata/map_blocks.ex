defmodule Ms2ex.Metadata.MapBlockCoords do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:field_id, :blocks]

  field :field_id, 1, type: :int32
  field :blocks, 2, repeated: true, type: Ms2ex.Metadata.Coord
end

defmodule Ms2ex.Metadata.MapBlocks do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:items]

  field :items, 1, repeated: true, type: Ms2ex.Metadata.MapBlockCoords

  @table :map_block_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-map-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{field_id: field_id, blocks: blocks} <- list.items do
      :ets.insert(@table, {field_id, blocks})
    end
  end

  def lookup(field_id) do
    case :ets.lookup(@table, field_id) do
      [{_id, blocks}] -> blocks
      _ -> []
    end
  end
end
