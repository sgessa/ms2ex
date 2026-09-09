defmodule Ms2ex.Types.Item do
  @moduledoc """
  Item metadata helpers.

  The inventory tab an item belongs to is derived from its property type,
  subtype and skin/fragment flags rather than the raw type value.
  """

  @type_tabs %{
    3 => :quest,
    5 => :mount,
    6 => :fishing_music,
    7 => :badge,
    9 => :mount,
    11 => :pets,
    12 => :fishing_music,
    13 => :gemstone,
    14 => :gemstone,
    15 => :catalyst,
    16 => :life_skill,
    18 => :consumable,
    19 => :catalyst,
    20 => :currency,
    21 => :lapenshard,
    22 => :misc
  }

  @badge_types %{
    702 => :chat_bubble,
    703 => :name_tag,
    704 => :damage,
    705 => :tombstone,
    706 => :swim_tube,
    707 => :fishing,
    708 => :buddy,
    709 => :effect
  }

  @spec inventory_tab(map()) :: atom()
  def inventory_tab(%{property: %{is_fragment: true}}), do: :fragment
  def inventory_tab(%{property: %{type: 1, is_skin: true}}), do: :outfit
  def inventory_tab(%{property: %{type: 1}}), do: :gear

  def inventory_tab(%{property: %{type: 10, subtype: 20}}), do: :fishing_music

  def inventory_tab(%{property: %{type: type, subtype: 2}}) when type in [0, 2, 4],
    do: :consumable

  def inventory_tab(%{property: %{type: type, subtype: _}}) when type in [0, 2, 4], do: :misc

  def inventory_tab(%{property: %{type: type}}), do: Map.get(@type_tabs, type, :misc)

  @doc "Returns the wire badge type derived from a badge item id."
  def badge_type(item_id) when is_integer(item_id) do
    badge_group = div(item_id, 100_000)

    if badge_group == 701 do
      %{0 => :pet_skin, 1 => :transparency}
      |> Map.get(rem(item_id, 10), :auto_gather)
    else
      Map.get(@badge_types, badge_group, :none)
    end
  end
end
