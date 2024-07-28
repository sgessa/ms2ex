defmodule Ms2ex.ProtoMetadata.Items.TransferType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :tradeable, 0
  field :untradeable, 1
  field :bind_on_loot, 2
  field :bind_on_equip, 3
  field :bind_on_use, 4
  field :bind_on_trade, 5
  field :tradeable_on_black_market, 6
  field :bind_on_summon_enchant_or_reroll, 7
end
