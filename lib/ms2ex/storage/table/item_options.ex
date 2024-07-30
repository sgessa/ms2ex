defmodule Ms2ex.Storage.Tables.ItemOptions do
  alias Ms2ex.Storage.Metadata

  def find_constant(constant_id, rarity) do
    :table
    |> Metadata.get("itemoptionconstant.xml")
    |> Map.get(:table)
    |> get_in([:options, constant_id, rarity])
  end

  def find_pick(pick_id, rarity) do
    :table
    |> Metadata.get("itemoptionpick.xml")
    |> Map.get(:table)
    |> get_in([:options, pick_id, rarity])
  end

  def find_random(random_id, rarity) do
    :table
    |> Metadata.get("itemoptionrandom.xml")
    |> Map.get(:table)
    |> get_in([:options, random_id, rarity])
  end

  def find_static(static_id, rarity) do
    :table
    |> Metadata.get("itemoptionstatic.xml")
    |> Map.get(:table)
    |> get_in([:options, static_id, rarity])
  end
end
