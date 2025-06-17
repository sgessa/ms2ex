defmodule Ms2ex.Context.ItemTypes do
  @item_types %{
    112 => :earring,
    113 => :hat,
    114 => :clothes,
    115 => :pants,
    116 => :gloves,
    117 => :shoes,
    118 => :cape,
    119 => :necklace,
    120 => :ring,
    121 => :belt,
    122 => :overall,
    130 => :bludgeon,
    131 => :dagger,
    132 => :longsword,
    133 => :scepter,
    134 => :throwing_star,
    140 => :spellbook,
    141 => :shield,
    150 => :greatsword,
    151 => :bow,
    152 => :staff,
    153 => :cannon,
    154 => :blade,
    155 => :knuckle,
    156 => :orb,
    209 => :medal,
    600 => :pet,
    900 => :currency
  }

  # Groups of item types with the same classification
  @lapenshard_ids [410, 420, 430]
  @furnishing_ids [501, 502, 503, 504, 505]

  def get_type_by_item_id(item_id) do
    item_type_id = trunc(item_id / 100_000)

    cond do
      Map.has_key?(@item_types, item_type_id) -> @item_types[item_type_id]
      item_type_id in @lapenshard_ids -> :lapenshard
      item_type_id in @furnishing_ids -> :furnishing
      true -> :none
    end
  end
end
