defmodule Ms2ex.Enums.CaughtFishType do
  @moduledoc "Which mastery notice the client shows for a caught fish."

  use Ms2ex.Enum, %{
    default: 1,
    first_kind: 2,
    prize: 3
  }
end
