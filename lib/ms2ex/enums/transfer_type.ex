defmodule Ms2ex.Enums.TransferType do
  use Ms2ex.Enum, %{
    tradeable: 0,
    untradeable: 1,
    bind_on_loot: 2,
    bind_on_equip: 3,
    bind_on_use: 4,
    bind_on_trade: 5,
    black_market_only: 6,
    bind_pet: 7
  }
end
