defmodule Ms2ex.Enums.WalletCurrencyType do
  @moduledoc """
  Currency ids on the wallet wire: the CurrencyToken packet and the mesos /
  merets packets carry these ids for token currencies. Plural atoms mirror
  the wallet columns. Shop entries, the meret market and smart-push packages
  use their own currency enums (see `ShopCurrencyType`, `MeretMarketCurrency`
  and `SmartPushCurrencyType`) — the same currency has a different id in
  each of them.
  """

  use Ms2ex.Enum, %{
    mesos: 0x0,
    valor_tokens: 0x3,
    trevas: 0x4,
    rues: 0x5,
    havi_fruits: 0x6,
    merets: 0x7,
    game_merets: 0x8,
    event_merets: 0x9,
    meso_tokens: 0x10
  }
end
