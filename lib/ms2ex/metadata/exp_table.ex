defmodule Ms2ex.Metadata.ExpTableEntry do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :level, 1, type: :int32
  field :to_next_level, 2, type: :int32
end

defmodule Ms2ex.Metadata.ExpTable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.ExpTableEntry

  field :items, 1, repeated: true, type: ExpTableEntry

  @table :exp_table_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-exp-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{level: level, to_next_level: tnl} <- list.items do
      :ets.insert(@table, {level, tnl})
    end
  end

  def to_next_level(level) do
    case :ets.lookup(@table, level) do
      [{_id, tnl}] -> {:ok, tnl}
      _ -> :error
    end
  end
end
