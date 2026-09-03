defmodule Ms2ex.Enums.QuestState do
  @moduledoc """
  Quest progression states as serialized in quest packets and rows.
  """

  use Ms2ex.Enum, %{
    none: 0,
    started: 1,
    completed: 2,
    failed: 3,
    abandoned: 4
  }
end
