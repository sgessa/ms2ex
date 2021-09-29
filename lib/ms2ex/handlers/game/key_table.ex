defmodule Ms2ex.GameHandlers.KeyTable do
  require Logger

  alias Ms2ex.{CharacterManager, HotBar, HotBars, Net, Packets, QuickSlot}

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  defp handle_mode(0x3, packet, session) do
    {id, packet} = get_short(packet)
    {:ok, char} = CharacterManager.lookup(session.character_id)
    hot_bars = HotBars.list(char)

    with %HotBar{} = active_hot_bar <- Enum.at(hot_bars, id) do
      {quick_slot, packet} = QuickSlot.get_quick_slot(packet)
      {target_slot, _packet} = get_int(packet)

      case HotBars.move_quick_slot(active_hot_bar, quick_slot, target_slot) do
        {:ok, _hot_bar} ->
          hot_bars = HotBars.list(char)
          push(session, Packets.KeyTable.send_hot_bars(hot_bars))

        _ ->
          session
      end
    else
      _ ->
        session
    end
  end

  defp handle_mode(0x5, packet, session) do
    {id, packet} = get_short(packet)
    {:ok, char} = CharacterManager.lookup(session.character_id)
    hot_bars = HotBars.list(char)

    with %HotBar{} = active_hot_bar <- Enum.at(hot_bars, id) do
      {skill_id, packet} = get_int(packet)
      {item_uid, _packet} = get_long(packet)

      case HotBars.remove_quick_slot(active_hot_bar, skill_id, item_uid) do
        {:ok, _hot_bar} ->
          hot_bars = HotBars.list(char)
          push(session, Packets.KeyTable.send_hot_bars(hot_bars))

        _ ->
          session
      end
    else
      _ ->
        session
    end
  end

  defp handle_mode(_mode, _packet, session), do: session
end
