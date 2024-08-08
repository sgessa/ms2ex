defmodule Ms2ex.Packets.SkillDamage do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @modes %{target: 0x0, damage: 0x1}

  def target(skill_cast, targets) do
    __MODULE__
    |> build()
    |> put_byte(@modes.target)
    |> put_long(skill_cast.id)
    |> put_int(skill_cast.caster.object_id)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_byte(skill_cast.motion_point)
    |> put_byte(skill_cast.attack_point)
    |> put_short_coord(skill_cast.position)
    |> put_coord(skill_cast.direction)
    # TODO: FIXME ??? should be bool
    |> put_byte()
    |> put_int(skill_cast.server_tick)
    |> put_byte(length(targets))
    |> reduce(targets, fn
      target, packet ->
        packet
        |> put_long(target.prev_uid)
        |> put_long(target.uid)
        |> put_int(target.target_id)
        |> put_byte(target.unknown)
        |> put_byte(target.index)
    end)
  end

  def damage(skill_cast, mobs, attk_counter) do
    caster = skill_cast.caster

    __MODULE__
    |> build()
    |> put_byte(@modes.damage)
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
