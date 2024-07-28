defmodule Ms2ex.ProtoMetadata.Items.GemSlot do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :trans, 1
  field :damage, 2
  field :chat, 3
  field :name, 4
  field :tombstone, 5
  field :swim, 6
  field :buddy, 7
  field :fishing, 8
  field :gather, 9
  field :effect, 10
  field :pet, 11
  field :unknown, 12
end
