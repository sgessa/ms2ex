defmodule Ms2ex.Packets.RegionSkill do
  alias Ms2ex.Packets
  alias Ms2ex.Types.SkillCast

  import Packets.PacketWriter

  @modes %{add: 0x0, remove: 0x1}

  def add(source_id, skill_cast) do
    points = SkillCast.magic_path(skill_cast)

    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(source_id)
    |> put_int(source_id)
    |> put_int(skill_cast.next_tick)
    |> put_byte(length(points))
    |> reduce(points, fn point, packet ->
      put_coord(packet, point)
    end)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    # RotationH
    |> put_float(region_rotation_z(skill_cast))
    # RotationV / 100
    |> put_float()
  end

  defp region_rotation_z(skill_cast) do
    if SkillCast.splash_use_direction?(skill_cast) do
      skill_cast.rotation.z
    else
      0.0
    end
  end

  def remove(source_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove)
    |> put_int(source_id)
  end
end
