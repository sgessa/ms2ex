defmodule Ms2ex.Packets.SkillUse do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(
        skill_cast,
        {position, direction, rotation, rotate2z},
        {unknown, is_hold, hold_int, hold_string}
      ) do
    packet =
      __MODULE__
      |> build()
      |> put_long(skill_cast.id)
      |> put_int(skill_cast.server_tick)
      |> put_int(skill_cast.character_object_id)
      |> put_int(skill_cast.skill_id)
      |> put_short(skill_cast.skill_level)
      |> put_byte()
      |> put_short_coord(position)
      |> put_coord(direction)
      |> put_coord(rotation)
      |> put_short(trunc(rotate2z) * 10)
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
