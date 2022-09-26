defmodule Ms2ex.Metadata.MapBlock do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :coord, 1, type: Ms2ex.Metadata.Coord
  field :attr, 2, type: :string
  field :type, 3, type: :string
  field :saleable_group, 4, type: :int32
end

defmodule Ms2ex.Metadata.Map do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :name, 2, type: :string
  field :x_block_name, 3, type: :string
  field :blocks, 4, repeated: true, type: Ms2ex.Metadata.MapBlock
end

defmodule Ms2ex.Metadata.Maps do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :items, 1, repeated: true, type: Ms2ex.Metadata.Map

  @table :map_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-map-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: field_id} = metadata <- list.items do
      :ets.insert(@table, {field_id, metadata})
    end
  end

  def lookup(field_id) do
    case :ets.lookup(@table, field_id) do
      [{_id, blocks}] -> blocks
      _ -> []
    end
  end
end
