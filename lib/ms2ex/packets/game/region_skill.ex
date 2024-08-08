defmodule Ms2ex.Packets.RegionSkill do
  alias Ms2ex.{Packets, Managers}

  import Packets.PacketWriter

  @modes %{add: 0x0, remove: 0x1}

  def add(source_id, skill_cast) do
    points = Managers.SkillCast.magic_path(skill_cast)

    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(source_id)
    |> put_int(skill_cast.caster.object_id)
    |> put_int(skill_cast.next_tick)
    |> put_byte(length(points))
    |> reduce(points, fn point, packet ->
      put_coord(packet, point)
    end)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    # RotationH
    |> put_float(skill_cast.rotation.z)
    # RotationV / 100
    |> put_float()
  end

  def remove(source_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove)
    |> put_int(source_id)
  end
end
