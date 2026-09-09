defmodule Ms2ex.GameHandlers.BadgeEquip do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    case command do
      0x0 ->
        {item_uid, _packet} = get_long(packet)
        Managers.Character.call(session.character_id, {:equip_badge, item_uid})

      0x1 ->
        {badge_type, _packet} = get_byte(packet)
        Managers.Character.call(session.character_id, {:unequip_badge, badge_type})

      0x3 ->
        {badge_type, packet} = get_byte(packet)
        {transparency, _packet} = get_bools(packet, 10, [])

        Managers.Character.call(
          session.character_id,
          {:update_badge_transparency, badge_type, transparency}
        )

      _ ->
        :ok
    end
  end

  defp get_bools(packet, 0, values), do: {Enum.reverse(values), packet}

  defp get_bools(packet, count, values) do
    {value, packet} = get_bool(packet)
    get_bools(packet, count - 1, [value | values])
  end
end
