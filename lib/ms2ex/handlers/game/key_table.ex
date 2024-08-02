defmodule Ms2ex.GameHandlers.KeyTable do
  require Logger

  alias Ms2ex.{CharacterManager, Context, Net, Packets, Schema, Types}

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Move Quick Slot
  defp handle_mode(0x3, packet, session) do
    {id, packet} = get_short(packet)
    {:ok, char} = CharacterManager.lookup(session.character_id)
    hot_bars = Context.HotBars.list(char)

    with %Schema.HotBar{} = active_hot_bar <- Enum.at(hot_bars, id) do
      {quick_slot, packet} = Types.QuickSlot.get_quick_slot(packet)
      {target_slot, _packet} = get_int(packet)

      with {:ok, _hot_bar} <-
             Context.HotBars.move_quick_slot(active_hot_bar, quick_slot, target_slot) do
        hot_bars = Context.HotBars.list(char)
        push(session, Packets.KeyTable.send_hot_bars(hot_bars))
      end
    end
  end

  # Remove Quick Slot
  defp handle_mode(0x5, packet, session) do
    {id, packet} = get_short(packet)
    {:ok, char} = CharacterManager.lookup(session.character_id)
    hot_bars = Context.HotBars.list(char)

    with %Schema.HotBar{} = active_hot_bar <- Enum.at(hot_bars, id) do
      {skill_id, packet} = get_int(packet)
      {item_uid, _packet} = get_long(packet)

      with {:ok, _hot_bar} <-
             Context.HotBars.remove_quick_slot(active_hot_bar, skill_id, item_uid) do
        hot_bars = Context.HotBars.list(char)
        push(session, Packets.KeyTable.send_hot_bars(hot_bars))
      end
    end
  end

  defp handle_mode(_mode, _packet, session), do: session
end
