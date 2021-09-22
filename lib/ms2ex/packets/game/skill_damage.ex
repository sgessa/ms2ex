defmodule Ms2ex.Packets.SkillDamage do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(object_id, skill_cast, value, coords, mobs) do
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
    |> put_short_coord()
    |> put_byte(length(mobs))
    |> reduce(mobs, fn %{damage: dmg} = mob, packet ->
      packet
      |> put_int(mob.object_id)
      |> put_byte(0x1)
      |> put_bool(dmg.is_critical)
      |> put_long(-dmg.dmg)
    end)
  end

  def sync_damage(skill_cast, {position, rotation}, character, target_count, projectiles) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_long(skill_cast.id)
    |> put_int(character.object_id)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_byte(skill_cast.motion_point)
    |> put_byte(skill_cast.attack_point)
    |> put_short_coord(position)
    |> put_coord(rotation)
    |> put_byte()
    |> put_int(skill_cast.server_tick)
    |> put_byte(target_count)
    |> reduce(0..target_count, fn
      0, packet ->
        packet

      idx, packet ->
        packet
        |> put_long()
        |> put_int(Enum.at(projectiles.attk_count, idx))
        |> put_int(Enum.at(projectiles.source_ids, idx))
        |> put_int(Enum.at(projectiles.target_ids, idx))
        |> put_short(Enum.at(projectiles.animations, idx))
        |> put_byte()
        |> put_byte()
    end)
  end
end
