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
    |> put_bool(true)
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

  def damage(skill_cast, mobs) do
    caster = skill_cast.caster

    __MODULE__
    |> build()
    |> put_byte(@modes.damage)
    # SkillUid: the damage record carries no cast reference; TargetUid links
    # the hit to the target (caster object id in the high dword + per-attack
    # counter in the low dword), which the client's HP-bar logic keys on
    |> put_long(0)
    |> put_long(caster.object_id * 0x1_0000_0000 + (skill_cast.attack_counter || 0))
    |> put_int(caster.object_id)
    |> put_int(skill_cast.skill_id)
    |> put_short(skill_cast.skill_level)
    |> put_byte(skill_cast.motion_point)
    |> put_byte(skill_cast.attack_point)
    |> put_short_coord(skill_cast.position)
    |> put_short_coord(skill_cast.rotation)
    |> put_byte(length(mobs))
    |> reduce(mobs, fn {mob, effect}, packet ->
      packet
      |> put_int(mob.object_id)
      # one damage entry: [type, amount]
      |> put_byte(0x1)
      |> put_byte(if(effect.crit?, do: 0x1, else: 0x0))
      |> put_long(effect.dmg)
    end)
  end

  # heal record layout: [caster][target][owner][hp][sp][ep] + animate flag;
  # unused amounts stay zero
  def heal(record) do
    __MODULE__
    |> build()
    |> put_byte(0x4)
    |> put_int(record.caster_id)
    |> put_int(record.target_id)
    |> put_int(record.owner_id)
    |> put_int(Map.get(record, :hp_amount, 0))
    |> put_int(Map.get(record, :sp_amount, 0))
    |> put_int(Map.get(record, :ep_amount, 0))
    |> put_bool(true)
  end

  # dot record layout: [caster][target][proc][type][hp]; hp is negative
  def dot_damage(record) do
    __MODULE__
    |> build()
    |> put_byte(0x3)
    |> put_int(record.caster_id)
    |> put_int(record.target_id)
    |> put_int(record.proc_count)
    |> put_byte(record.type)
    |> put_int(record.hp_amount)
  end
end
