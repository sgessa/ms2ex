defmodule Ms2ex.GameHandlers.FallDamage do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader, only: [get_float: 1]

  def handle(packet, session) do
    {fall_distance, _packet} = get_float(packet)
    damage_distance = fall_distance - 1000.0

    if damage_distance > 0 do
      Managers.Character.cast(session.character_id, {:receive_fall_dmg, damage_distance})

      progress = trunc(fall_distance / 150)

      if progress > 0 do
        {:ok, character} = Managers.Character.lookup(session.character_id)
        Managers.Quest.update_conditions(character.id, :fall, progress)
      end
    end
  end
end
