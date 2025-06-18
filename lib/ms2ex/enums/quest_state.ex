defmodule Ms2ex.Enums.QuestState do
  @moduledoc """
  Enum for quest states.
  Ported from Maple2's QuestState enum.
  """

  use Ms2ex.Enum, %{
    none: 0,
    started: 1,
    completed: 2,
    failed: 3,
    abandoned: 4
  }
end
