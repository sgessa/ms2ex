defmodule Ms2ex.Enums.MasteryType do
  @moduledoc """
  Life skill (mastery) types. The order doubles as the wire order of the
  mastery block written into the character packet.
  """

  use Ms2ex.Enum, %{
    unknown: 0,
    fishing: 1,
    music: 2,
    mining: 3,
    gathering: 4,
    breeding: 5,
    farming: 6,
    blacksmithing: 7,
    engraving: 8,
    alchemist: 9,
    cooking: 10,
    pet_taming: 11
  }

  @ordered [
    :fishing,
    :music,
    :mining,
    :gathering,
    :breeding,
    :farming,
    :blacksmithing,
    :engraving,
    :alchemist,
    :cooking,
    :pet_taming
  ]

  @maximums %{
    fishing: 2990,
    music: 10_800,
    mining: 81_440,
    gathering: 81_440,
    breeding: 81_440,
    farming: 81_440,
    blacksmithing: 81_440,
    engraving: 81_440,
    alchemist: 81_440,
    cooking: 81_440,
    pet_taming: 100_000
  }

  @doc "Every real mastery type, in wire order."
  def ordered, do: @ordered

  @doc "The mastery cap of a type."
  def maximum(type), do: Map.get(@maximums, type, 0)
end
