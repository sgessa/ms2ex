defmodule Ms2ex.Metadata.InventoryTab do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :gear, 0
  field :outfit, 1
  field :mount, 2
  field :catalyst, 3
  field :fishing_music, 4
  field :quest, 5
  field :gemstone, 6
  field :misc, 7
  field :life_skill, 9
  field :pets, 10
  field :consumable, 11
  field :currency, 12
  field :badge, 13
  field :lapenshard, 15
  field :fragment, 16
end

defmodule Ms2ex.Metadata.GemSlot do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :trans, 1
  field :damage, 2
  field :chat, 3
  field :name, 4
  field :tombstone, 5
  field :swim, 6
  field :buddy, 7
  field :fishing, 8
  field :gather, 9
  field :effect, 10
  field :pet, 11
  field :unknown, 12
end

defmodule Ms2ex.Metadata.EquipSlot do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :NONE, 0
  field :HR, 102
  field :FA, 103
  field :FD, 104
  field :ER, 105
  field :FH, 110
  field :EY, 111
  field :EA, 112
  field :CP, 113
  field :CL, 114
  field :PA, 115
  field :GL, 116
  field :SH, 117
  field :MT, 118
  field :PD, 119
  field :RI, 120
  field :BE, 121
  field :RH, 1
  field :LH, 2
  field :OH, 3
end

defmodule Ms2ex.Metadata.ItemContent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :id2, 2, type: :int32
  field :min_amount, 3, type: :int32
  field :max_amount, 4, type: :int32
  field :drop_group, 5, type: :int32
  field :smart_drop_rate, 6, type: :int32
  field :rarity, 7, type: :int32
  field :enchant_level, 8, type: :int32
end

defmodule Ms2ex.Metadata.DismantleReward do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :item_id, 1, type: :int32
  field :amount, 2, type: :int32
end

defmodule Ms2ex.Metadata.Item do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :id,
    :slot,
    :gem_slot,
    :tab,
    :rarity,
    :stack_limit,
    :dismantable?,
    :is_two_handed?,
    :is_dress?,
    :is_template?,
    :play_count,
    :skill_id,
    :jobs,
    :content
  ]

  field :id, 1, type: :int32
  field :slot, 2, type: Ms2ex.Metadata.EquipSlot, enum: true
  field :gem_slot, 3, type: Ms2ex.Metadata.GemSlot, enum: true
  field :tab, 4, type: Ms2ex.Metadata.InventoryTab, enum: true
  field :rarity, 5, type: :int32
  field :stack_limit, 6, type: :int32
  field :dismantable?, 7, type: :bool
  field :is_two_handed?, 8, type: :bool
  field :is_dress?, 9, type: :bool
  field :is_template?, 10, type: :bool
  field :play_count, 11, type: :int32
  field :file_name, 12, type: :string
  field :skill_id, 13, type: :int32
  field :jobs, 14, repeated: true, type: Ms2ex.Metadata.Job, enum: true
  field :content, 15, repeated: true, type: Ms2ex.Metadata.ItemContent
  field :dismantle_rewards, 16, repeated: true, type: Ms2ex.Metadata.DismantleReward
  field :function_name, 17, type: :string
  field :function_param, 18, type: :int32
end

defmodule Ms2ex.Metadata.Items do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Item

  defstruct [:items]

  field :items, 1, repeated: true, type: Item

  @table :item_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: item_id} = metadata <- list.items do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def load(item) do
    case lookup(item.item_id) do
      {:ok, meta} ->
        rarity = item.rarity || meta.rarity
        %{item | metadata: meta, rarity: rarity}

      :error ->
        item
    end
  end

  def lookup(item_id) do
    case :ets.lookup(@table, item_id) do
      [{_id, %Item{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
