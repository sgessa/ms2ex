defmodule Ms2ex.Packets.Skill do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def use_skill(_character, value, skill_uid, coords) do
    active_skill_id = 1
    active_skill_level = 1

    __MODULE__
    |> build()
    |> put_long(skill_uid)
    |> put_int(value)
    |> put_int(active_skill_id)
    |> put_short(active_skill_level)
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
