defmodule Ms2ex.Enums.GuildFocus do
  use Ms2ex.Enum, %{
    none: 0,
    social: 1,
    hunting_parties: 2,
    trophy_collection: 4,
    dungeons: 8,
    home_design: 16,
    pvp: 32,
    workshop_templates: 64,
    guild_arcade: 128,
    weekdays: 256,
    mornings: 512,
    weekends: 1024,
    evenings: 2048,
    teens: 4096,
    thirties: 8192,
    twenties: 16_384,
    other: 32_768
  }
end
