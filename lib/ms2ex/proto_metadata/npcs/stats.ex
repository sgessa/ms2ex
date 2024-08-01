defmodule Ms2ex.ProtoMetadata.NpcStat do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :bonus, 1, type: :int32
  field :base, 2, type: :int32
  field :total, 3, type: :int32
end

defmodule Ms2ex.ProtoMetadata.NpcStats do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.NpcStat

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
