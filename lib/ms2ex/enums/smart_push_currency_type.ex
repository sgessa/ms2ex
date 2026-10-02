defmodule Ms2ex.Enums.SmartPushCurrencyType do
  @moduledoc """
  Currency ids of smart-push auto-action packages. Not the wallet wire ids —
  see `WalletCurrencyType`.
  """

  use Ms2ex.Enum, %{
    none: 0,
    meso: 1,
    meret: 2
  }
end
