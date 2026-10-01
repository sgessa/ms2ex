defmodule Ms2ex.GameHandlers.Shop do
  @moduledoc """
  Vendor shop requests: buy, sell, buy-back and restock on the open shop.
  """

  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  @purchase_buy_back 0x3
  @buy 0x4
  @sell 0x5
  @instant_restock 0x9
  @refresh 0xA

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id) do
      case command do
        @purchase_buy_back ->
          {entry_id, _packet} = get_int(packet)
          Managers.Shop.purchase_buy_back(character, entry_id)

        @buy ->
          {shop_item_id, packet} = get_int(packet)
          {quantity, _packet} = get_int(packet)
          Managers.Shop.buy(character, shop_item_id, quantity)

        @sell ->
          {item_uid, packet} = get_long(packet)
          {quantity, _packet} = get_int(packet)
          Managers.Shop.sell(character, item_uid, quantity)

        @instant_restock ->
          {_cost, _packet} = get_int(packet)
          Managers.Shop.instant_restock(character)

        @refresh ->
          Managers.Shop.refresh(character)

        _command ->
          :ok
      end
    end

    :ok
  end
end
