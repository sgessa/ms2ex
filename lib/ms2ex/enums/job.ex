defmodule Ms2ex.Enums.Job do
  use Ms2ex.Enum, %{
    none: 0,
    unknown: 1,
    knight: 10,
    berserker: 20,
    wizard: 30,
    priest: 40,
    archer: 50,
    heavy_gunner: 60,
    thief: 70,
    assassin: 80,
    rune_blade: 90,
    striker: 100,
    soul_binder: 110,
    game_master: 999
  }
end
