defmodule Ms2ex.Enums.MeretMarketCurrency do
  @moduledoc """
  Currency ids of meret-market entries. Not the wallet wire ids — see
  `WalletCurrencyType`.
  """

  use Ms2ex.Enum, %{
    meso: 0,
    meret: 1,
    red_meret: 2
  }
end
