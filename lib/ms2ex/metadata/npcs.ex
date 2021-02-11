defmodule Ms2ex.Metadata.NpcStat do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:total, :min, :max]

  field :total, 1, type: :int32
  field :min, 2, type: :int32
  field :max, 3, type: :int32
end

defmodule Ms2ex.Metadata.NpcStats do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.NpcStat

  field :str, 1, type: NpcStat
  field :dex, 2, type: NpcStat
  field :int, 3, type: NpcStat
  field :luk, 4, type: NpcStat
  field :hp, 5, type: NpcStat
  field :hp_regen, 6, type: NpcStat
  field :hp_inv, 7, type: NpcStat
  field :sp, 8, type: NpcStat
  field :sp_regen, 9, type: NpcStat
  field :sp_inv, 10, type: NpcStat
  field :ep, 11, type: NpcStat
  field :ep_regen, 12, type: NpcStat
  field :ep_inv, 13, type: NpcStat
  field :attk_speed, 14, type: NpcStat
  field :move_speed, 15, type: NpcStat
  field :attk, 16, type: NpcStat
  field :evasion, 17, type: NpcStat
  field :cap, 18, type: NpcStat
  field :cad, 19, type: NpcStat
  field :car, 20, type: NpcStat
  field :ndd, 21, type: NpcStat
  field :abp, 22, type: NpcStat
  field :jump_height, 23, type: NpcStat
  field :phys_attk, 24, type: NpcStat
  field :mag_attk, 25, type: NpcStat
  field :phys_res, 26, type: NpcStat
  field :mag_res, 27, type: NpcStat
  field :min_attk, 28, type: NpcStat
  field :max_attk, 29, type: NpcStat
  field :damage, 30, type: NpcStat
  field :pierce, 31, type: NpcStat
  field :mount_speed, 32, type: NpcStat
  field :bonus_attk, 33, type: NpcStat
  field :pet_bonus_attk, 34, type: NpcStat
end

defmodule Ms2ex.Metadata.Npc do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.{Coord, NpcStats}

  defstruct [
    :id,
    :model,
    :friendly,
    :level,
    :stats,
    :skill_ids,
    :ai_info,
    :exp,
    :dead_at,
    :dead_actions,
    :drop_box_ids,
    :rotation,
    :speed,
    :position,
    :animation
  ]

  field :id, 1, type: :int32
  field :model, 2, type: :string
  field :friendly, 3, type: :int32
  field :level, 4, type: :int32
  field :stats, 5, type: NpcStats
  field :skill_ids, 6, repeated: true, type: :int32
  field :ai_info, 7, type: :string
  field :exp, 8, type: :int32
  field :dead_at, 9, type: :float
  field :dead_actions, 10, repeated: true, type: :string
  field :drop_box_ids, 11, repeated: true, type: :int32
  field :rotation, 12, type: Coord
  field :speed, 13, type: Coord
  field :position, 14, type: Coord
  field :animation, 15, type: :int32
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
      [{_id, %Npc{} = meta}] -> meta
      _ -> nil
    end
  end

  def lookup(npc_id) do
    case get(npc_id) do
      nil -> :error
      mob -> {:ok, mob}
    end
  end
end
