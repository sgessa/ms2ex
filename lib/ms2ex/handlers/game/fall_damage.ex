defmodule Ms2ex.GameHandlers.FallDamage do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader, only: [get_float: 1]

  def handle(packet, session) do
    {distance, _packet} = get_float(packet)
    distance = distance - 1000.0

    if distance > 0 do
      Managers.Character.cast(session.character_id, {:receive_fall_dmg, distance})
    end
  end
end
