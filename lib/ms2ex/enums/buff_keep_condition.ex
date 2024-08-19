defmodule Ms2ex.Enums.BuffKeepCondition do
  use Ms2ex.Enum, %{
    timer_duration: 0,
    skill_duration: 1,
    timer_duration_track_cooldown: 5,
    unlimited_duration: 99
  }
end
