defmodule Ms2ex.Packets.Skill do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def use_skill(skill_cast, value, coords) do
    __MODULE__
    |> build()
    |> put_long(skill_cast.id)
    |> put_int(value)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.level)
    |> put_byte()
    |> put_coord(coords)
    |> put_long()
    |> put_long()
    |> put_int()
    |> put_short()
    |> put_int()
    |> put_byte()
    |> put_byte()
  end
end
