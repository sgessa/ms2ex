defmodule Ms2ex.Metadata.Npc do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata
  alias Metadata.Coord

  defstruct [
    :id,
    :name,
    :model,
    :template_id,
    :friendly,
    :level,
    :skill_ids,
    :ai_info,
    :exp,
    :drop_box_ids,
    :rotation,
    :walk_speed,
    :run_speed,
    :position,
    :stats,
    :basic,
    :combat,
    :dead,
    :distance,
    :interact,
    animation: 255,
    boss?: false,
    respawn?: true
  ]

  field :id, 1, type: :int32
  field :name, 2, type: :string
  field :model, 3, type: :string
  field :template_id, 4, type: :int32
  field :friendly, 5, type: :int32
  field :level, 6, type: :int32
  field :skill_ids, 7, repeated: true, type: :int32
  field :skill_levels, 8, repeated: true, type: :int32
  field :skill_priorities, 9, repeated: true, type: :int32
  field :skill_probs, 10, repeated: true, type: :int32
  field :skill_cooldown, 11, type: :int32
  # field :state_actions, 12, repeated: true, type: Metadata.NpcAction
  field :ai_info, 13, type: :string
  field :exp, 14, type: :int32
  field :drop_box_ids, 15, repeated: true, type: :int32
  field :rotation, 16, type: Coord
  field :walk_speed, 17, type: :float
  field :run_speed, 18, type: :float
  field :move_range, 19, type: :int32
  field :position, 20, type: Coord
  field :animation, 21, type: :int32
  field :basic, 22, type: Metadata.NpcBasic
  field :combat, 23, type: Metadata.NpcCombat
  field :dead, 24, type: Metadata.NpcDead
  field :distance, 25, type: Metadata.NpcDistance
  field :interact, 26, type: Metadata.NpcInteract
  field :stats, 27, type: Metadata.NpcStats
  field :type, 28, type: :int32
  field :shop_id, 29, type: :int32
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

  def from_main_tag(tag) do
    @table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, npc} -> tag in npc.basic.main_tags end)
    |> Enum.map(fn {_id, npc} -> npc end)
  end
end
