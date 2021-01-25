defmodule Ms2ex.Protobuf.InventoryTab do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :gear
          | :outfit
          | :mount
          | :catalyst
          | :fishing_music
          | :quest
          | :gemstone
          | :misc
          | :life_skill
          | :pets
          | :consumable
          | :currency
          | :badge
          | :lapenshard
          | :fragment

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

defmodule Ms2ex.Protobuf.GemSlot do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :none
          | :trans
          | :damage
          | :chat
          | :name
          | :tombstone
          | :swim
          | :buddy
          | :fishing
          | :gather
          | :effect
          | :pet
          | :unknown

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

defmodule Ms2ex.Protobuf.ItemSlot do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :NONE
          | :HR
          | :FA
          | :FD
          | :ER
          | :FH
          | :EY
          | :EA
          | :CP
          | :CL
          | :PA
          | :GL
          | :SH
          | :MT
          | :PD
          | :RI
          | :BE
          | :RH
          | :LH
          | :OH

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

defmodule Ms2ex.Protobuf.ItemContent do
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

defmodule Ms2ex.Protobuf.ItemMetadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: integer,
          slot: Ms2ex.Protobuf.ItemSlot.t(),
          gem_slot: Ms2ex.Protobuf.GemSlot.t(),
          tab: Ms2ex.Protobuf.InventoryTab.t(),
          rarity: integer,
          max_slot: integer,
          is_template: boolean
        }

  defstruct [:id, :slot, :gem_slot, :tab, :rarity, :max_slot, :is_template]

  field :id, 1, type: :int32
  field :slot, 2, type: Ms2ex.Protobuf.ItemSlot, enum: true
  field :gem_slot, 3, type: Ms2ex.Protobuf.GemSlot, enum: true
  field :tab, 4, type: Ms2ex.Protobuf.InventoryTab, enum: true
  field :rarity, 5, type: :int32
  field :max_slot, 6, type: :int32
  field :is_template, 7, type: :bool
  field :play_count, 8, type: :int32
  field :recommended_jobs, 9, repeated: true, type: :int32
  field :content, 10, repeated: true, type: Ms2ex.Protobuf.ItemContent
end

defmodule Ms2ex.Protobuf.ListItemMetadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          items: [ItemMetadata.t()]
        }

  defstruct [:items]

  field :items, 1, repeated: true, type: Ms2ex.Protobuf.ItemMetadata
end
