defmodule Ms2ex.Metadata.Items.MedalSlot do
    @moduledoc false
    use Protobuf, enum: true, syntax: :proto3

    field :tail, 0
    field :ground_mount, 1
    field :glider, 2
end
