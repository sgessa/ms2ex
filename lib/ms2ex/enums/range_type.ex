defmodule Ms2ex.Enums.RegionType do
  use Ms2ex.Enum, %{
    :none => 0,
    :box => 1,
    :cylinder => 2,
    :frustum => 3,
    :hole_cylinder => 4
  }
end
