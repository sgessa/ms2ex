defmodule Ms2ex.Enums.AchievementRewardType do
  use Ms2ex.Enum, %{
    none: 0,
    item: 1,
    title: 2,
    stat_point: 3,
    skill_point: 4,
    shop_weapon: 5,
    shop_build: 6,
    shop_ride: 7,
    item_coloring: 8,
    beauty_makeup: 9,
    beauty_skin: 10,
    beauty_hair: 11,
    dynamic_action: 12,
    etc: 13
  }
end
