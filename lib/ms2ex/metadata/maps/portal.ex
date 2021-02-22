defmodule Ms2ex.Metadata.MapPortal do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @flags [none: 0, visible: 1, enabled: 2, minimap_visible: 4]

  defstruct [:id, :flags, :target, :coord, :rotation]

  field :id, 1, type: :int32
  field :flags, 2, type: :int32
  field :target, 3, type: :int32
  field :coord, 4, type: Ms2ex.Metadata.Coord
  field :rotation, 5, type: Ms2ex.Metadata.Coord

  def has_flag?(portal, flag) do
    flag_value = Keyword.get(@flags, flag)
    Bitwise.band(portal.flags, flag_value) != 0
  end
end
