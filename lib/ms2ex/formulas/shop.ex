defmodule Ms2ex.Formulas.Shop do
  @moduledoc """
  Vendor shop pricing: what an npc pays for a sold item and how instant
  restock prices escalate with repeated restocks.
  """

  # weekly resets land on this day (thursday)
  @reset_weekday 4

  # vendor prices for level 57+ gear, indexed by rarity
  @level_57_prices [1541, 1926, 2465, 9256, 11_339, 13_653]

  @weapon_types 30..59
  @armor_types 13..17

  @doc """
  The meso value an npc shop pays for an item of the given metadata and
  rarity. Gear sells at a third of its price; the client's fixed prices
  replace the table for level 57+ gear.
  """
  @spec sell_price(map(), integer(), integer()) :: integer()
  def sell_price(metadata, item_type, rarity) do
    level = get_in(metadata, [:limit, :level]) || 0

    if level >= 57 do
      Enum.at(@level_57_prices, rarity - 1) || 0
    else
      custom_prices = get_in(metadata, [:property, :custom_sell_prices]) || []
      prices = get_in(metadata, [:property, :sell_prices]) || []

      price = Enum.at(custom_prices, rarity - 1) || 0

      if price > 0 do
        sell_gear_price(price, item_type, rarity)
      else
        sell_gear_price(Enum.at(prices, rarity - 1) || 0, item_type, rarity)
      end
    end
  end

  # gear (group 1) below legendary rarity sells at a third of its price
  defp sell_gear_price(price, {1, type}, rarity)
       when rarity < 4 and (type in @weapon_types or type in @armor_types or type == 22),
       do: floor(price * 0.333)

  defp sell_gear_price(price, _item_type, _rarity), do: price

  # instant restock starts at a flat meso fee for the first handful of
  # restocks, then switches to the shop's excess currency and scales up
  @spec excess_restock_cost(atom(), integer()) :: {atom(), integer()}
  def excess_restock_cost(_excess_currency_type, restock_count) when restock_count in 1..5,
    do: {:meso, 50_000}

  def excess_restock_cost(excess_currency_type, restock_count) when restock_count in 11..15,
    do: {excess_currency_type, 100}

  def excess_restock_cost(excess_currency_type, restock_count) when restock_count in 6..10,
    do: {excess_currency_type, tier_restock_cost(restock_count)}

  def excess_restock_cost(excess_currency_type, _restock_count),
    do: {excess_currency_type, 150}

  defp tier_restock_cost(6), do: 10
  defp tier_restock_cost(7), do: 20
  defp tier_restock_cost(8), do: 40
  defp tier_restock_cost(9), do: 60
  defp tier_restock_cost(_restock_count), do: 80

  @doc "The next date strictly after `date` that is the weekly reset day."
  def next_reset_day(%Date{} = date) do
    days_until = rem(@reset_weekday - Date.day_of_week(date) + 7, 7)
    days_until = if days_until == 0, do: 7, else: days_until
    Date.add(date, days_until)
  end
end
