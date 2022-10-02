defmodule Ms2ex.Metadata.Items.SkinType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :special, 1
  field :normal, 2
  field :event, 3
  field :in_game_obtainable, 4
  field :default, 99
end
