defmodule Ms2ex.Packets.RegionSkill do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @modes %{add: 0x0, remove: 0x1}

  def add(field_skill) do
    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(field_skill.object_id)
    |> put_int(field_skill.caster.object_id)
    |> put_int(field_skill.next_tick)
    |> put_byte(length(field_skill.points))
    |> reduce(field_skill.points, fn point, packet ->
      put_coord(packet, point)
    end)
    |> put_int(field_skill.skill_id)
    |> put_short(field_skill.skill_level)
    # RotationH
    |> put_float(field_skill.rotation.z)
    # RotationV / 100
    |> put_float()
  end

  def remove(object_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove)
    |> put_int(object_id)
  end
end
