defmodule Ms2ex.Enums.GuideObjectType do
  @moduledoc "Client-side markers a player controls."

  use Ms2ex.Enum, %{
    construction: 0,
    fishing: 1,
    skill_guide: 2
  }
end
