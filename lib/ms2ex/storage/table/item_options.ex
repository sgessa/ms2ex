defmodule Ms2ex.Storage.Tables.ItemOptions do
  alias Ms2ex.Storage

  def find_constant(constant_id, rarity) do
    :table
    |> Storage.get("itemoptionconstant.xml")
    |> get_in([:table, :options, to_string(constant_id), to_string(rarity)])
  end

  def find_pick(pick_id, rarity) do
    :table
    |> Storage.get("itemoptionpick.xml")
    |> get_in([:table, :options, to_string(pick_id), to_string(rarity)])
  end

  def find_random(random_id, rarity) do
    :table
    |> Storage.get("itemoptionrandom.xml")
    |> get_in([:table, :options, to_string(random_id), to_string(rarity)])
  end

  def find_static(static_id, rarity) do
    :table
    |> Storage.get("itemoptionstatic.xml")
    |> get_in([:table, :options, to_string(static_id), to_string(rarity)])
  end
end
