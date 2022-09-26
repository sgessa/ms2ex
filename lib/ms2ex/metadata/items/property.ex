defmodule Ms2ex.Metadata.Items.Property do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :stack_limit, 1, type: :int32
  field :skin_type, 2, enum: true, type: Ms2ex.Metadata.Items.SkinType
  field :category, 3, type: :string
  field :black_market_category, 4, type: :string
  field :disable_attribute_change, 5, type: :bool
  field :gear_score_factor, 6, type: :int32
  field :tradeable_count, 7, type: :int32
  field :repackage_count, 8, type: :int32
  field :repackage_item_consume_count, 9, type: :int32
  field :disable_trade_within_account, 10, type: :bool
  field :disable_drop, 11, type: :bool
  field :socket_data_id, 12, type: :int32
  field :sell, 13, type: Ms2ex.Metadata.Items.Sell
end
