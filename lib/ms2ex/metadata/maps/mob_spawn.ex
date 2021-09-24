# defmodule Ms2ex.Metadata.MobSpawn do
#   @moduledoc false
#   use Protobuf, syntax: :proto3

#   defstruct [:id, :position, :npc_count, :npc_ids, :spawn_radius, :data]

#   field :id, 1, type: :int32
#   field :position, 2, type: Ms2ex.Metadata.Coord
#   field :npc_count, 3, type: :int32
#   field :npc_ids, 4, repeated: true, type: :int32
#   field :spawn_radius, 3, type: :int32
#   field :data, 4, type: Ms2ex.Metadata.MobSpawnData
# end
