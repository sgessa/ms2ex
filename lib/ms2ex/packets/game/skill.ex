defmodule Ms2ex.Packets.Skill do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def use_skill(skill_cast, {position, direction, rotation}) do
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
    |> put_short()
    |> put_byte()
    |> put_byte()
  end
end
