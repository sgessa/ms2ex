defmodule Ms2ex.Packets.SkillUse do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(skill_cast, {unknown, is_hold, hold_int, hold_string}) do
    packet =
      __MODULE__
      |> build()
      |> put_long(skill_cast.id)
      |> put_int(skill_cast.server_tick)
      |> put_int(skill_cast.caster.object_id)
      |> put_int(skill_cast.skill_id)
      |> put_short(skill_cast.skill_level)
      |> put_byte()
      |> put_short_coord(skill_cast.position)
      |> put_coord(skill_cast.direction)
      |> put_coord(skill_cast.rotation)
      |> put_short(trunc(skill_cast.rotate2z) * 10)
      |> put_bool(unknown)
      |> put_bool(is_hold)

    if is_hold do
      packet
      |> put_int(hold_int)
      |> put_ustring(hold_string)
    else
      packet
    end
  end
end
