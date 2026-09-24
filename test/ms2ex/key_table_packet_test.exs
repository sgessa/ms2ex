defmodule Ms2ex.KeyTablePacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketReader

  def key_bind(key_code), do: %Types.KeyBind{key_code: key_code, option_type: 1, option_guid: 99}

  def empty_bar do
    %Schema.HotBar{id: 1, active: true, quick_slots: List.duplicate(%Types.QuickSlot{}, 25)}
  end

  test "key binds round-trip through the wire format" do
    packet = Types.KeyBind.put_key_bind(<<>>, key_bind(18))

    {bind, rest} = Types.KeyBind.get_key_bind(packet)
    assert bind.key_code == 18
    assert bind.option_type == 1
    assert bind.option_guid == 99
    assert rest == <<>>
  end

  test "load carries binds and bars under the load mode with the default flag cleared" do
    bytes =
      Packets.KeyTable.load(%{18 => key_bind(18), 19 => key_bind(19)}, [empty_bar(), empty_bar()])

    {_opcode, packet} = get_short(bytes)
    {mode, packet} = get_byte(packet)
    assert mode == 0x0

    {use_defaults?, packet} = get_bool(packet)
    refute use_defaults?

    {bind_count, packet} = get_int(packet)
    assert bind_count == 2

    {first, packet} = Types.KeyBind.get_key_bind(packet)
    {second, packet} = Types.KeyBind.get_key_bind(packet)
    assert first.key_code in [18, 19]
    assert second.key_code in [18, 19]
    assert first.key_code != second.key_code

    {active_index, packet} = get_short(packet)
    assert active_index == 0

    {bar_count, packet} = get_short(packet)
    assert bar_count == 2

    {slot_count, packet} = get_int(packet)
    assert slot_count == 25

    {slot_index, _packet} = get_int(packet)
    {slot, _packet} = Types.QuickSlot.get_quick_slot(packet)
    assert slot_index == 0
    assert slot == %Types.QuickSlot{}
  end

  test "request is a load-mode packet flagged as defaults" do
    bytes = Packets.KeyTable.request()

    {_opcode, packet} = get_short(bytes)
    {mode, packet} = get_byte(packet)
    assert mode == 0x0

    {use_defaults?, rest} = get_bool(packet)
    assert use_defaults?
    assert rest == <<>>
  end
end
