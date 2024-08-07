defmodule Ms2ex.ProtoMetadata.MagicPathMove do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :rotation, 1, type: :int32
  field :fire_offset_position, 2, type: Ms2ex.Metadata.CoordF
  field :direction, 3, type: Ms2ex.Metadata.CoordF
  field :control_value_0, 4, type: Ms2ex.Metadata.CoordF
  field :control_value_1, 5, type: Ms2ex.Metadata.CoordF
  field :ignore_adjust, 6, type: :bool
end

defmodule Ms2ex.ProtoMetadata.MagicPath do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :moves, 2, repeated: true, type: Ms2ex.ProtoMetadata.MagicPathMove
end

defmodule Ms2ex.ProtoMetadata.MagicPaths do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @table :magic_path_metadata

  field :items, 1, repeated: true, type: Ms2ex.ProtoMetadata.MagicPath

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-magicpath-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: item_id} = metadata <- list.items do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def get(path_id) do
    case :ets.lookup(@table, path_id) do
      [{_id, meta}] -> meta
      _ -> nil
    end
  end
end
