defmodule Ms2ex.GameHandlers.Inventory do
  require Logger

  alias Ms2ex.{CharacterManager, Context, Field, Net, Packets, Schema, TransferFlags}

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Move / Swap
  defp handle_mode(0x3, packet, session) do
    {id, packet} = get_long(packet)
    {dst_slot, _packet} = get_short(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %Schema.Item{inventory_slot: src_slot} = src_item <-
           Context.Inventory.get(character, id),
         {:ok, dst_uid} <- Context.Inventory.swap(src_item, dst_slot) do
      push(session, Packets.InventoryItem.move_item(dst_uid, src_slot, src_item.id, dst_slot))
    end
  end

  # Drop
  defp handle_mode(0x4, packet, session) do
    {id, packet} = get_long(packet)
    {amount, _packet} = get_int(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %Schema.Item{} = item <- Context.Inventory.get(character, id),
         true <- TransferFlags.has_flag?(item.transfer_flags, :tradeable),
         true <- TransferFlags.has_flag?(item.transfer_flags, :splittable) do
      consumed_item = Context.Inventory.consume(item, amount)
      Field.drop_item(character, %{item | amount: amount})
      update_inventory(session, consumed_item)
    end
  end

  # Drop Bound
  defp handle_mode(0x5, packet, session) do
    {id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %Schema.Item{} = item <- Context.Inventory.get(character, id) do
      update_inventory(session, Context.Inventory.delete(item))
    end
  end

  # Sort
  defp handle_mode(0xA, packet, session) do
    {tab, _packet} = get_short(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, items} <- Context.Inventory.sort_tab(character, tab) do
      session
      |> push(Packets.InventoryItem.reset_tab(tab))
      |> push(Packets.InventoryItem.load_items(tab, items))
    end
  end

  # Expand
  defp handle_mode(0xB, packet, session) do
    {tab, _packet} = get_byte(packet)

    meret_price = -390

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, wallet} <- Context.Wallets.update(character, :merets, meret_price),
         %Schema.InventoryTab{tab: tab, slots: slots} <-
           Context.Inventory.expand_tab(character, tab) do
      session
      |> push(Packets.Wallet.update(wallet, :merets))
      |> push(Packets.InventoryItem.load_tab(tab, slots))
      |> push(Packets.InventoryItem.expand_tab())
    end
  end

  defp handle_mode(_mode, _packet, session), do: session

  defp update_inventory(session, {:update, item}) do
    push(session, Packets.InventoryItem.update_item(item.id, item.amount))
  end

  defp update_inventory(session, {:delete, item}) do
    push(session, Packets.InventoryItem.remove_item(item.id))
  end
end
