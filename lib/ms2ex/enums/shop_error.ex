defmodule Ms2ex.Enums.ShopError do
  use Ms2ex.Enum, %{
    lack_shopitem: 2,
    invalid_item: 4,
    cant_sell: 9,
    lack_meso: 10,
    lack_merat: 11,
    inventory: 14,
    lack_guild_trophy: 15,
    lack_payment_item: 17,
    lack_guild_require_date: 19,
    anti_addiction_cannot_receive: 22,
    cant_sell_to_only_sell_shop: 23,
    system_property_protection_time: 24,
    guild_buy_no_master: 25,
    not_enough_guild_fund: 26,
    invalid_item_cannot_buy_by_period: 27,
    no_star_point_event: 29,
    meratmarket_error_country_limit: 31,
    cannot_sell_petitem_summon: 32
  }
end
