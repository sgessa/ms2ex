defmodule Ms2ex.Enums.RegionType do
  @mapping %{
    :none => 0,
    :box => 1,
    :cylinder => 2,
    :frustum => 3,
    :hole_cylinder => 4
  }

  use Ms2ex.Enums
end
