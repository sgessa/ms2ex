defmodule Ms2ex.Metadata.Items.StaticOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Items

  field :rarity, 1, type: :int32
  field :defense_calibration_factor, 2, type: :float
  field :hidden_def_add, 3, type: :int32
  field :weapon_attk_calibration_factor, 4, type: :float
  field :hidden_weapon_attk_add, 5, type: :int32
  field :hidden_bonus_attk_add, 6, type: :int32
  field :slots, 7, repeated: true, type: :int32
  field :stats, 8, repeated: true, type: Items.Stat
  field :special_stats, 9, repeated: true, type: Items.Stat
end
