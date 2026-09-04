defmodule Ms2ex.Context.CharacterStats do
  alias Ms2ex.Context.ItemStats
  alias Ms2ex.Context.StatPoints
  alias Ms2ex.Schema

  def apply(%Schema.Character{} = character, equips) do
    {character, equipment_stats} = ItemStats.apply(character, equips)
    {StatPoints.apply(character), equipment_stats}
  end
end
