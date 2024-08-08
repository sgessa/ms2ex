defmodule Ms2ex.Packets.SkillDamage do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def damage(skill_cast, mobs, attk_counter) do
    caster = skill_cast.caster

    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_long(skill_cast.id)
    |> put_int(attk_counter)
    |> put_int(caster.object_id)
    |> put_int(caster.object_id)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_byte(skill_cast.motion_point)
    |> put_byte(skill_cast.motion_point)
    |> put_short_coord(skill_cast.position)
    |> put_short_coord(skill_cast.rotation)
    |> put_byte(length(mobs))
    |> reduce(mobs, fn {mob, effect}, packet ->
      packet
      |> put_int(mob.object_id)
      |> put_bool(effect.dmg > 0)
      |> put_bool(effect.crit?)
      |> maybe_put_dmg(effect.dmg)
    end)
  end

  defp maybe_put_dmg(packet, dmg) when dmg != 0 do
    put_long(packet, -dmg)
  end

  defp maybe_put_dmg(packet, _dmg), do: packet

  def sync_damage(skill_cast, target_count, projectiles) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_long(skill_cast.id)
    |> put_int(skill_cast.caster.object_id)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_byte(skill_cast.motion_point)
    |> put_byte(skill_cast.motion_point)
    |> put_short_coord(skill_cast.position)
    |> put_coord(skill_cast.rotation)
    |> put_byte()
    |> put_int(skill_cast.server_tick)
    |> put_byte(target_count)
    |> reduce(0..target_count, fn
      0, packet ->
        packet

      idx, packet ->
        packet
        |> put_long()
        |> put_int(Enum.at(projectiles.attk_count, idx - 1))
        |> put_int(Enum.at(projectiles.source_ids, idx - 1))
        |> put_int(Enum.at(projectiles.target_ids, idx - 1))
        |> put_short(Enum.at(projectiles.animations, idx - 1))
        |> put_byte()
        |> put_byte()
    end)
  end

  def heal(status, heal_amount) do
    __MODULE__
    |> build()
    |> put_byte(0x4)
    |> put_int(status.source)
    |> put_int(status.target)
    |> put_int(status.id)
    |> put_int(heal_amount)
    |> put_long()
    |> put_byte(0x1)
  end
end
