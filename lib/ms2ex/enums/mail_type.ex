defmodule Ms2ex.Enums.MailType do
  use Ms2ex.Enum, %{
    player: 1,
    system: 101,
    black_market_sale: 102,
    black_market_fail: 103,
    black_market_listing_cancel: 104,
    meso_market: 106,
    wedding_system: 111,
    wedding_invite: 112,
    ad: 200
  }
end
