defmodule Ms2ex.Enums.BadgeType do
  use Ms2ex.Enum, %{
    none: 0,
    transparency: 1,
    damage: 2,
    chat_bubble: 3,
    name_tag: 4,
    tombstone: 5,
    swim_tube: 6,
    buddy: 7,
    fishing: 8,
    auto_gather: 9,
    effect: 10,
    pet_skin: 11
  }
end
