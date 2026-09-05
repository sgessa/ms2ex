defmodule Ms2ex.Enums.MasteryError do
  @moduledoc "Error codes the client renders for mastery (life skill) actions."

  use Ms2ex.Enum, %{
    none: 0,
    s_mastery_error_lack_mastery: 1,
    s_mastery_error_lack_meso: 2,
    s_mastery_error_lack_quest: 3,
    s_mastery_error_lack_item: 4,
    s_mastery_error_unknown: 5,
    s_mastery_error_invalid_level: 7,
    s_anti_addiction_cannot_receive: 12
  }
end
