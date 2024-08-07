defmodule Ms2ex.Packets.SkillSync do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(skill_cast) do
    __MODULE__
    |> build()
    |> put_long(skill_cast.cast_id)
    |> put_int(skill_cast.character_object_id)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_byte(skill_cast.motion_point)
    |> put_coord(skill_cast.position)
    |> put_coord(skill_cast.direction)
    |> put_coord(skill_cast.rotation)
    |> put_coord()
    |> put_byte()
    |> put_byte(skill_cast.attack_point)
    |> put_int()
  end
end
