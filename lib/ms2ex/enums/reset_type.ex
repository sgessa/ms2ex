defmodule Ms2ex.Enums.ResetType do
  use Ms2ex.Enum, %{
    default: 0,
    day: 1,
    week: 2,
    month: 3,
    unlimited: 99
  }
end
