defmodule Ms2ex.Metadata.NpcBasic do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :attack_group,
    :defense_group,
    :attack_dmg,
    :hit_immune,
    :abnormal_immune,
    :class,
    :kind,
    :hp_bar,
    :rotation_disabled,
    :care_path_to_enemy,
    :max_spawn_count,
    :group_spawn_count,
    :rare_degree,
    :difficulty,
    :race,
    property_tags: [],
    event_tags: []
  ]

  field :attack_group, 1, type: :int32
  field :defense_group, 2, type: :int32
  field :attack_dmg, 3, type: :bool
  field :hit_immune, 4, type: :bool
  field :abnormal_immune, 5, type: :bool
  field :class, 6, type: :int32
  field :kind, 7, type: :int32
  field :hp_bar, 8, type: :int32
  field :rotation_disabled, 9, type: :bool
  field :care_path_to_enemy, 10, type: :bool
  field :max_spawn_count, 11, type: :int32
  field :group_spawn_count, 12, type: :int32
  field :rare_degree, 13, type: :int32
  field :difficulty, 14, type: :int32
  field :property_tags, 15, repeated: true, type: :string
  field :main_tags, 16, repeated: true, type: :string
  field :sub_tags, 17, repeated: true, type: :string
  field :event_tags, 18, repeated: true, type: :string
  field :race, 19, type: :string
end
