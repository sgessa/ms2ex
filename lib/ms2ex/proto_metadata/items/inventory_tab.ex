defmodule Ms2ex.ProtoMetadata.Items.InventoryTab do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :gear, 0
  field :outfit, 1
  field :mount, 2
  field :catalyst, 3
  field :fishing_music, 4
  field :quest, 5
  field :gemstone, 6
  field :misc, 7
  field :life_skill, 9
  field :pets, 10
  field :consumable, 11
  field :currency, 12
  field :badge, 13
  field :lapenshard, 15
  field :fragment, 16
end
