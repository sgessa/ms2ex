defmodule Ms2ex.Packets.Shop do
  @moduledoc """
  Vendor shop window packets: opening a shop, its stock, buy results and
  the session's buy-back list.
  """

  alias Ms2ex.Enums
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketWriter

  @commands %{
    open: 0x0,
    load_items: 0x1,
    update: 0x2,
    buy: 0x4,
    buy_back_item_count: 0x6,
    load_buy_back: 0x7,
    remove_buy_back: 0x8,
    instant_restock: 0x9,
    error: 0xF
  }

  # Open(npcId, shop): the npc id titles the shop window
  def open(%{} = shop, npc_id, character) do
    __MODULE__
    |> build()
    |> put_byte(@commands.open)
    |> put_int(npc_id)
    |> put_shop(shop)
    |> put_shop_items(shop.items, character)
  end

  # LoadItems(items): the stock list of the open shop
  def load_items(%{} = shop, character) do
    __MODULE__
    |> build()
    |> put_byte(@commands.load_items)
    |> put_shop_items(shop.items, character)
  end

  # Update(id, totalQuantityPurchased): stock left of a limited entry
  def update(shop_item_id, quantity_purchased) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update)
    |> put_int(shop_item_id)
    |> put_int(quantity_purchased)
  end

  # Buy(itemId, totalItems, totalPrice, rarity, toGuildStorage)
  def buy(item_id, total_items, total_price, rarity, to_guild_storage? \\ false) do
    __MODULE__
    |> build()
    |> put_byte(@commands.buy)
    |> put_int(item_id)
    |> put_int(total_items)
    |> put_int(total_price)
    |> put_byte(rarity)
    |> put_bool(to_guild_storage?)
  end

  def buy_back_item_count(count) do
    __MODULE__
    |> build()
    |> put_byte(@commands.buy_back_item_count)
    |> put_short(count)
  end

  def load_buy_back(buy_back_items, character) do
    __MODULE__
    |> build()
    |> put_byte(@commands.load_buy_back)
    |> put_short(length(buy_back_items))
    |> reduce(buy_back_items, fn buy_back, packet ->
      put_buy_back_item(packet, buy_back, character)
    end)
  end

  def remove_buy_back(entry_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.remove_buy_back)
    |> put_int(entry_id)
  end

  def instant_restock do
    __MODULE__
    |> build()
    |> put_byte(@commands.instant_restock)
    |> put_bool(false)
  end

  def error(error, arg1 \\ 0, arg2 \\ 0) do
    __MODULE__
    |> build()
    |> put_byte(@commands.error)
    |> put_int(Enums.ShopError.get_value(error))
    |> put_byte(arg1)
    |> put_int(arg2)
  end

  defp put_shop(packet, shop) do
    meta = shop.metadata
    restock = Map.get(meta, :restock, %{})

    packet
    |> put_int(shop.id)
    |> put_long(shop.restock_time)
    |> put_int()
    |> put_short(map_size(shop.items))
    |> put_int(Map.get(meta, :category_id, 0))
    |> put_bool(Map.get(meta, :open_wallet, false))
    |> put_bool(Map.get(meta, :is_only_sell, false))
    |> put_bool(Map.get(meta, :enable_reset, false))
    |> put_bool(Map.get(meta, :disable_display_order_sort, false))
    |> put_byte(Enums.ShopFrameType.get_value(frame_type(Map.get(meta, :frame_type))))
    |> put_bool(Map.get(meta, :display_only_usable, false))
    |> put_bool(Map.get(meta, :hide_stats, false))
    |> put_bool(false)
    |> put_bool(Map.get(meta, :display_new, false))
    |> put_string(Map.get(meta, :name, ""))
    |> put_restock(shop, restock)
  end

  defp put_restock(packet, shop, restock) do
    if Map.get(shop.metadata, :enable_reset, false) do
      packet
      |> put_byte(Enums.ShopCurrencyType.get_value(currency_type(restock.currency_type)))
      |> put_byte(Enums.ShopCurrencyType.get_value(currency_type(restock.excess_currency_type)))
      |> put_int()
      |> put_int(Map.get(restock, :price, 0))
      |> put_bool(Map.get(restock, :enable_price_multiplier, false))
      |> put_int(shop.restock_count)
      |> put_byte(Enums.ResetType.get_value(reset_type(restock.reset_type)))
      |> put_bool(Map.get(restock, :disable_instant_restock, false))
      |> put_bool(Map.get(restock, :account_wide, false))
    else
      packet
    end
  end

  defp put_shop_items(packet, items, character) do
    packet
    |> put_byte(map_size(items))
    |> reduce(items, fn {_id, shop_item}, packet ->
      put_shop_item(packet, shop_item, character)
    end)
  end

  defp put_shop_item(packet, shop_item, character) do
    meta = shop_item.metadata
    requirements = Map.get(meta, :requirements, %{})
    cost = Map.get(meta, :cost, %{})
    achievement = Map.get(requirements, :achievement, %{})
    championship = Map.get(requirements, :championship, %{})
    guild_npc = Map.get(requirements, :guild_npc, %{})
    quest_alliance = Map.get(requirements, :quest_alliance, %{})
    restricted_buy = Map.get(meta, :restricted_buy)
    sell_unit = Map.get(meta, :sell_unit, 0)

    packet
    |> put_int(shop_item.id)
    |> put_int(Map.get(meta, :item_id, 0))
    |> put_cost(cost)
    |> put_byte(Map.get(meta, :rarity, 1))
    |> put_int(500)
    |> put_int(stock_count(shop_item))
    |> put_int(Map.get(shop_item, :stock_purchased, 0) * sell_unit)
    |> put_int(Map.get(requirements, :guild_trophy, 0))
    |> put_string(Map.get(meta, :category, ""))
    |> put_int(Map.get(achievement, :id, 0))
    |> put_int(Map.get(achievement, :rank, 0))
    |> put_byte(Map.get(championship, :rank, 0))
    |> put_short(Map.get(championship, :join_count, 0))
    |> put_byte(Map.get(guild_npc, :type, 0))
    |> put_short(Map.get(guild_npc, :level, 0))
    |> put_bool(false)
    |> put_short(sell_unit)
    |> put_byte()
    |> put_byte(Enums.ShopItemLabel.get_value(label(Map.get(meta, :label))))
    |> put_string(Map.get(meta, :icon_tag, ""))
    |> put_short(Enums.ReputationType.get_value(reputation_type(quest_alliance.type)))
    |> put_int(Map.get(quest_alliance, :grade, 0))
    |> put_bool(Map.get(meta, :wear_for_preview, false))
    |> put_bool(restricted_buy != nil)
    |> put_restricted_buy(restricted_buy)
    |> Packets.InventoryItem.put_item(shop_item.item, character)
  end

  defp put_cost(packet, cost) do
    packet
    |> put_byte(Enums.ShopCurrencyType.get_value(currency_type(cost.type)))
    |> put_int(Map.get(cost, :item_id, 0))
    |> put_int()
    |> put_int(Map.get(cost, :amount, 0))
    |> put_int(Map.get(cost, :sale_amount, 0))
  end

  defp put_restricted_buy(packet, nil), do: packet

  defp put_restricted_buy(packet, restricted) do
    time_ranges = Map.get(restricted, :time_ranges, [])
    days = Map.get(restricted, :days, [])
    start_time = Map.get(restricted, :start_time, 0)
    end_time = Map.get(restricted, :end_time, 0)

    packet
    |> put_bool(start_time > 0 and end_time > 0)
    |> put_long(start_time)
    |> put_long(end_time)
    |> put_short(length(time_ranges))
    |> reduce(time_ranges, fn range, packet ->
      packet
      |> put_int(Map.get(range, :start, 0))
      |> put_int(Map.get(range, :end, 0))
    end)
    |> put_byte(length(days))
    |> reduce(days, fn day, packet ->
      put_byte(packet, Enums.ShopBuyDay.get_value(day))
    end)
  end

  defp put_buy_back_item(packet, buy_back, character) do
    item = buy_back.item

    packet
    |> put_int(buy_back.id)
    |> put_int(item.item_id)
    |> put_byte(item.rarity)
    |> put_long(buy_back.price)
    |> Packets.InventoryItem.put_item(item, character)
  end

  defp stock_count(%{stock_count: stock_count}) when is_integer(stock_count), do: stock_count

  defp stock_count(%{metadata: %{sell_count: sell_count}}) when is_integer(sell_count),
    do: sell_count

  defp stock_count(_shop_item), do: 0

  defp frame_type(type) when is_atom(type), do: type
  defp frame_type(type) when is_integer(type), do: Enums.ShopFrameType.get_key(type)
  defp frame_type(_), do: :default

  defp currency_type(type) when is_atom(type), do: type
  defp currency_type(type) when is_integer(type), do: Enums.ShopCurrencyType.get_key(type)
  defp currency_type(_), do: :meso

  defp reset_type(type) when is_atom(type), do: type
  defp reset_type(type) when is_integer(type), do: Enums.ResetType.get_key(type)
  defp reset_type(_), do: :default

  defp label(type) when is_atom(type), do: type
  defp label(type) when is_integer(type), do: Enums.ShopItemLabel.get_key(type)
  defp label(_), do: :none

  defp reputation_type(type) when is_atom(type), do: type
  defp reputation_type(type) when is_integer(type), do: Enums.ReputationType.get_key(type)
  defp reputation_type(_), do: :none
end
