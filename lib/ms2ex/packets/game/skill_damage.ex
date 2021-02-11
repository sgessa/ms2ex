defmodule Ms2ex.Packets.SkillDamage do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(object_id, skill_cast, value, coords, mobs) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_long(skill_cast.id)
    |> put_int(value)
    |> put_int(object_id)
    |> put_int(object_id)
    |> put_int(skill_cast.skill_id)
    |> put_int(skill_cast.level)
    |> put_short_coord(coords)
    |> put_short_coord()
    |> put_byte(length(mobs))
    |> reduce(mobs, fn %{damage: dmg} = mob, packet ->
      packet
      |> put_int(mob.object_id)
      |> put_byte(0x1)
      |> put_bool(dmg.is_critical)
      |> put_long(dmg.dmg)
    end)
  end
end
