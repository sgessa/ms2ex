defmodule Ms2ex.Types.QuickSlot do
  import Ms2ex.Packets.{PacketReader, PacketWriter}

  @type t :: %__MODULE__{}
  defstruct skill_id: 0x0, item_id: 0x0, item_uid: 0x0

  def get_quick_slot(packet) do
    {skill_id, packet} = get_int(packet)
    {item_id, packet} = get_int(packet)
    {item_uid, packet} = get_long(packet)

    quick_slot = %__MODULE__{skill_id: skill_id, item_id: item_id, item_uid: item_uid}
    {quick_slot, packet}
  end

  def put_quick_slot(packet, slot) do
    packet
    |> put_int(slot.skill_id)
    |> put_int(slot.item_id)
    |> put_long(slot.item_uid)
  end
end
