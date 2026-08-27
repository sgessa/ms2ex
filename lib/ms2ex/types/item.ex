defmodule Ms2ex.Types.Item do
  @moduledoc """
  Item metadata helpers.

  The inventory tab an item belongs to is derived from its property type,
  subtype and skin/fragment flags rather than the raw type value.
  """

  @spec inventory_tab(map()) :: atom()
  def inventory_tab(%{property: property}) do
    if property[:is_fragment] do
      :fragment
    else
      case property[:type] do
        0 -> tab_or(property, 2, :consumable, :misc)
        1 -> if(property[:is_skin], do: :outfit, else: :gear)
        2 -> tab_or(property, 2, :consumable, :misc)
        3 -> :quest
        4 -> tab_or(property, 2, :consumable, :misc)
        5 -> :mount
        6 -> :fishing_music
        7 -> :badge
        9 -> :mount
        10 -> if(property[:subtype] != 20, do: :misc, else: :fishing_music)
        11 -> :pets
        12 -> :fishing_music
        13 -> :gemstone
        14 -> :gemstone
        15 -> :catalyst
        16 -> :life_skill
        18 -> :consumable
        19 -> :catalyst
        20 -> :currency
        21 -> :lapenshard
        22 -> :misc
        _ -> :misc
      end
    end
  end

  defp tab_or(property, subtype, if_tab, else_tab) do
    if property[:subtype] == subtype, do: if_tab, else: else_tab
  end
end
