defmodule Ms2ex.Packets.SkillSync do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(
        character,
        cast_id,
        skill_id,
        skill_level,
        motion_point,
        position,
        direction,
        rotation,
        attack_point
      ) do
    __MODULE__
    |> build()
    |> put_long(cast_id)
    |> put_int(character.object_id)
    |> put_int(skill_id)
    |> put_short(skill_level)
    |> put_byte(motion_point)
    |> put_coord(position)
    |> put_coord(direction)
    |> put_coord(rotation)
    |> put_coord()
    |> put_byte()
    |> put_byte(attack_point)
    |> put_int()
  end
end
