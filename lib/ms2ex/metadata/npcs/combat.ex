defmodule Ms2ex.Metadata.NpcCombat do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :abandon_tick,
    :abandon_impossible_tick,
    :can_ignore_extended_lifetime,
    :can_show_hidden_target
  ]

  field :abandon_tick, 1, type: :int32
  field :abandon_impossible_tick, 2, type: :int32
  field :can_ignore_extended_lifetime, 3, type: :bool
  field :can_show_hidden_target, 4, type: :bool
end
