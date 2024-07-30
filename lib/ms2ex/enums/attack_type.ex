defmodule Ms2ex.Enums.AttackType do
  @mapping %{
    :none => 0,
    :physical => 1,
    :magic => 2,
    :unknown => 3
  }

  use Ms2ex.Enums
end
