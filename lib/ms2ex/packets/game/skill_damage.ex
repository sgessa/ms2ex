defmodule Ms2ex.Packets.SkillDamage do
  alias Ms2ex.Metadata.Coord
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def apply_damage(object_id, skill_cast, value, coords, _mobs) do
    coords = %Coord{x: trunc(coords.x), y: trunc(coords.y), z: trunc(coords.z)}
    IO.inspect(coords)

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
    |> put_short_coord(%Coord{x: 0, y: 0, z: 0})
    |> put_byte(0)
  end
end
