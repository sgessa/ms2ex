defmodule Ms2ex.Metadata.MobSpawnData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:difficulty, :min_difficulty, :tags, :spawn_time, :population, :pet_spawn?]

  field :difficulty, 1, type: :int32
  field :min_difficulty, 2, type: :int32
  field :tags, 3, repeated: true, type: :string
  field :spawn_time, 4, type: :int32
  field :population, 5, type: :int32
  field :pet_spawn?, 6, type: :bool
end
