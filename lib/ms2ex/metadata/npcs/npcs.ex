defmodule Ms2ex.Metadata.Npc do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata
  alias Metadata.Coord

  defstruct [
    :id,
    :name,
    :model,
    :friendly,
    :level,
    :skill_ids,
    :ai_info,
    :exp,
    :drop_box_ids,
    :rotation,
    :speed,
    :position,
    :stats,
    :basic,
    :combat,
    :dead,
    :distance,
    :interact,
    animation: 255
  ]

  field :id, 1, type: :int32
  field :name, 2, type: :string
  field :model, 3, type: :string
  field :friendly, 4, type: :int32
  field :level, 5, type: :int32
  field :skill_ids, 6, repeated: true, type: :int32
  field :ai_info, 7, type: :string
  field :exp, 8, type: :int32
  field :drop_box_ids, 9, repeated: true, type: :int32
  field :rotation, 10, type: Coord
  field :speed, 11, type: Coord
  field :position, 12, type: Coord
  field :animation, 13, type: :int32
  field :basic, 14, type: Metadata.NpcBasic
  field :combat, 15, type: Metadata.NpcCombat
  field :dead, 16, type: Metadata.NpcDead
  field :distance, 17, type: Metadata.NpcDistance
  field :interact, 18, type: Metadata.NpcInteract
  field :stats, 19, type: Metadata.NpcStats

  @extra %{is_boss?: false, dead?: false, direction: 2700, respawn: true, spawn: nil}
  def extra_fields(), do: @extra
end

defmodule Ms2ex.Metadata.Npcs do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Npc

  defstruct [:items]

  field :items, 1, repeated: true, type: Npc

  @table :npc_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-npc-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: npc_id} = metadata <- list.items do
      :ets.insert(@table, {npc_id, metadata})
    end
  end

  def get(npc_id) do
    case :ets.lookup(@table, npc_id) do
      [{_id, %Npc{} = meta}] ->
        meta
        |> Map.merge(Npc.extra_fields())
        |> Map.put(:dead_at, trunc(meta.dead.time) * 1000)

      _ ->
        nil
    end
  end

  def lookup(npc_id) do
    case get(npc_id) do
      nil -> :error
      mob -> {:ok, mob}
    end
  end
end
