defmodule Ms2ex.Enums.AttackType do
  use Ms2ex.Enum, %{
    :none => 0,
    :physical => 1,
    :magic => 2,
    :unknown => 3
  }
end
