defmodule Ms2ex.Packets.KeyTable do
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketWriter

  @modes %{
    request: 0x0,
    send_hot_bars: 0x7
  }

  def request() do
    __MODULE__
    |> build()
    |> put_byte(@modes.request)
    |> put_bool(true)
  end

  def send_hot_bars(hot_bars) do
    __MODULE__
    |> build()
    |> put_byte(@modes.send_hot_bars)
    |> put_hot_bars(hot_bars)
  end

  def put_hot_bars(packet, hot_bars) do
    active_hot_bar_id = Enum.find_index(hot_bars, & &1.active)

    packet
    |> put_short(active_hot_bar_id)
    |> put_short(length(hot_bars))
    |> reduce(hot_bars, fn hot_bar, packet ->
      slots_number = length(hot_bar.quick_slots)
      slots = Enum.with_index(hot_bar.quick_slots)

      packet
      |> put_int(slots_number)
      |> reduce(slots, fn {slot, idx}, packet ->
        packet
        |> put_int(idx)
        |> Types.QuickSlot.put_quick_slot(slot)
      end)
    end)
  end
end
