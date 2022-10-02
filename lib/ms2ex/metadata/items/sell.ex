defmodule Ms2ex.Metadata.Items.Sell do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :price, 1, repeated: true, type: :int64
  field :custom_price, 2, repeated: true, type: :int64
end
