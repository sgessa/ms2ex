defmodule Ms2ex.ProtoMetadata.Items.Limit do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :job_requirements, 1, repeated: true, type: :int32
  field :job_recommendations, 2, repeated: true, type: :int32
  field :level_limit_min, 3, type: :int32
  field :level_limit_max, 4, type: :int32
  field :gender, 5, enum: true, type: Ms2ex.ProtoMetadata.Items.Gender
  field :transfer_type, 6, enum: true, type: Ms2ex.ProtoMetadata.Items.TransferType
  field :sellable, 7, type: :bool
  field :breakable, 8, type: :bool
  field :meret_market_listable, 9, type: :bool
  field :disable_enchant, 10, type: :bool
  field :trade_limit_by_rarity, 11, type: :int32
  field :vip_only, 12, type: :bool
end
