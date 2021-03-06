defmodule Ms2ex.Metadata.MobSpawn do
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Coord

  defstruct [:map_id, :mob_id, :position]

  field :map_id, 1, type: :int32
  field :mob_id, 2, type: :int32
  field :position, 3, type: Coord
  field :is_boss?, 4, type: :bool
end

defmodule Ms2ex.Metadata.MobSpawns do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.MobSpawn

  defstruct [:items]

  field :items, 1, repeated: true, type: MobSpawn

  @table :mob_spawn_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-mob-spawn-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :bag, :named_table])

    for %{map_id: map_id} = mob <- list.items do
      :ets.insert(@table, {map_id, mob})
    end
  end

  def lookup_by_map(map_id) do
    case :ets.lookup(@table, map_id) do
      [] -> []
      results -> Enum.map(results, fn {_, mob} -> mob end)
    end
  end
end
