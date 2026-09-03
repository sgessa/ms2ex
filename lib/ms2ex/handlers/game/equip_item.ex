defmodule Ms2ex.GameHandlers.EquipItem do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Equip
  defp handle_mode(0x0, packet, session) do
    {id, packet} = get_long(packet)
    {slot_name, _packet} = get_ustring(packet)

    Managers.Character.call(session.character_id, {:equip_item, id, slot_name})
    session
  end

  # Unequip
  defp handle_mode(0x1, packet, session) do
    {id, _packet} = get_long(packet)

    Managers.Character.call(session.character_id, {:unequip_item, id})
    session
  end

  # Swap
  defp handle_mode(0x2, _packet, session), do: session
end
