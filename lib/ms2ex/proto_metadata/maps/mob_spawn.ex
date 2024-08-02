defmodule Ms2ex.ProtoMetadata.MobSpawn do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.{MapBlock, ProtoMetadata}
  alias Ms2ex.Types.Coord

  field :id, 1, type: :int32
  field :position, 2, type: Coord
  field :npc_count, 3, type: :int32
  field :npc_ids, 4, repeated: true, type: :int32
  field :spawn_radius, 5, type: :int32
  field :data, 6, type: ProtoMetadata.MobSpawnData

  def select_mobs(difficulty, min_difficulty, tags) do
    tags
    |> Enum.map(&ProtoMetadata.Npcs.from_main_tag(&1))
    |> List.flatten()
    |> Enum.filter(&(&1.basic.difficulty in min_difficulty..difficulty))
    |> Enum.reject(&(&1.name == "Constructor Type 13"))
  end

  def select_points(spawn_radius \\ MapBlock.block_size()) do
    spawn_size = 2 * trunc(spawn_radius / MapBlock.block_size())

    offsets =
      Enum.reduce(0..spawn_size, [], fn
        ^spawn_size, offsets ->
          offsets

        i, offsets ->
          Enum.reduce(0..spawn_size, offsets, fn
            ^spawn_size, offsets ->
              offsets

            j, offsets ->
              x = i * MapBlock.block_size() - spawn_radius
              y = j * MapBlock.block_size() - spawn_radius
              offsets ++ [%Coord{x: x, y: y, z: 0}]
          end)
      end)

    Enum.shuffle(offsets)
  end
end
