defmodule Ms2ex.Enums.ShopCurrencyType do
  @moduledoc """
  Payment currency ids as they appear in the shop tables (`payment_type`).
  Not the wallet wire ids — see `WalletCurrencyType` for those; the shop
  manager maps these onto wallet currencies.
  """

  use Ms2ex.Enum, %{
    meso: 0,
    item: 1,
    valor_token: 2,
    treva: 3,
    meret: 4,
    rue: 5,
    havi_fruit: 6,
    guild_coin: 7,
    reverse_coin: 8,
    event_meret: 9,
    game_meret: 10,
    mentor_token: 11,
    mentee_token: 12,
    star_point: 13,
    meso_token: 14
  }
end
