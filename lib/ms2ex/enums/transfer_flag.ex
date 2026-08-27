defmodule Ms2ex.Enums.TransferFlag do
  use Ms2ex.Enum, %{
    none: 0,
    split: 2,
    trade: 4,
    bind: 8,
    limit_trade: 16
  }
end
