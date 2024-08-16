defmodule Ms2ex.GameHandlers.Skill do
  require Logger

  alias Ms2ex.{Managers, Context, Net, Packets, Types}
  alias Ms2ex.Managers

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  @use 0x0
  @attack 0x1
  @sync 0x2
  @tick_sync 0x3
  @cancel 0x4

  @point 0x0
  @target 0x1
  @splash 0x2

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  def handle_mode(@use, packet, session) do
    {cast_id, packet} = get_long(packet)
    {server_tick, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {skill_level, packet} = get_short(packet)
    {motion_point, packet} = get_byte(packet)

    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {rotate2z, packet} = get_float(packet)

    {_client_tick, packet} = get_int(packet)

    {unknown, packet} = get_bool(packet)
    {_item_uid, packet} = get_long(packet)
    {is_hold, _packet} = get_bool(packet)

    {hold_int, hold_string, _packet} =
      if is_hold do
        {hold_int, packet} = get_int(packet)
        {hold_string, packet} = get_ustring(packet)

        {hold_int, hold_string, packet}
      else
        {nil, nil, packet}
      end

    {:ok, character} = Managers.Character.lookup(session.character_id)

    skill_cast =
      Types.SkillCast.build(character, %{
        id: cast_id,
        skill_id: skill_id,
        skill_level: skill_level,
        position: position,
        direction: direction,
        rotation: rotation,
        rotate2z: rotate2z,
        motion_point: motion_point,
        server_tick: server_tick,
        unknown: unknown,
        is_hold: is_hold,
        hold_int: hold_int,
        hold_string: hold_string
      })

    {:ok, character} = Managers.Character.call(character, {:cast_skill, skill_cast})

    Context.Field.broadcast(character, Packets.SkillUse.bytes(skill_cast))
  end

  def handle_mode(@attack, packet, session) do
    {damage_type, packet} = get_byte(packet)
    handle_damage(damage_type, packet, session)
  end

  def handle_mode(@sync, packet, session) do
    {cast_id, packet} = get_long(packet)
    {_skill_id, packet} = get_int(packet)
    {_skill_level, packet} = get_int(packet)
    {motion_point, packet} = get_byte(packet)

    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {_input, packet} = get_coord(packet)
    {_toggle, packet} = get_byte(packet)
    {_unk3, packet} = get_byte(packet)
    {_unk4, _packet} = get_byte(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if skill_cast = character.skill_casts[cast_id] do
      Managers.Character.Skill.update(character, skill_cast, %{
        motion_point: motion_point,
        position: position,
        direction: direction,
        rotation: rotation
      })

      Context.Field.broadcast(skill_cast.caster, Packets.SkillSync.bytes(skill_cast))
    end
  end

  def handle_mode(@tick_sync, packet, session) do
    {cast_id, packet} = get_long(packet)
    {server_tick, _packet} = get_int(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if skill_cast = character.skill_casts[cast_id] do
      Managers.Character.Skill.update(character, skill_cast, %{
        server_tick: server_tick
      })
    end
  end

  def handle_mode(@cancel, packet, session) do
    {cast_id, _packet} = get_long(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if skill_cast = character.skill_casts[cast_id] do
      Context.Field.broadcast(skill_cast.caster, Packets.SkillCancel.bytes(skill_cast))
    end
  end

  defp handle_damage(@point, packet, session) do
    {cast_id, packet} = get_long(packet)
    {attack_point, packet} = get_byte(packet)
    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {target_count, packet} = get_byte(packet)
    {_iterations, packet} = get_int(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if skill_cast = character.skill_casts[cast_id] do
      Managers.Character.Skill.update(character, skill_cast, %{
        position: position,
        direction: direction,
        attack_point: attack_point
      })

      damage_targets(packet, target_count, skill_cast)
    end
  end

  defp handle_damage(@target, packet, session) do
    {cast_id, packet} = get_long(packet)
    {attack_counter, packet} = get_int(packet)
    {_char_obj_id, packet} = get_int(packet)

    {position, packet} = get_coord(packet)
    {_impact_pos, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {_motion_point, packet} = get_byte(packet)

    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if skill_cast = character.skill_casts[cast_id] do
      Managers.Character.Skill.update(character, skill_cast, %{
        position: position,
        rotation: rotation
      })

      crit? = Context.Damage.roll_crit(skill_cast.caster)
      mobs = damage_targets(skill_cast, crit?, target_count, [], packet)

      # TODO
      # handle splash and/or conditions

      Context.Field.broadcast(
        skill_cast.caster,
        Packets.SkillDamage.damage(skill_cast, mobs, attack_counter)
      )
    end
  end

  # AoE Damage
  defp handle_damage(@splash, packet, session) do
    {cast_id, packet} = get_long(packet)
    {attack_point, packet} = get_byte(packet)
    {_, packet} = get_int(packet)
    {_, packet} = get_int(packet)
    {position, packet} = get_coord(packet)
    {rotation, _packet} = get_coord(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if skill_cast = character.skill_casts[cast_id] do
      {:ok, character, skill_cast} =
        Managers.Character.Skill.update(character, skill_cast, %{
          attack_point: attack_point,
          position: position,
          rotation: rotation
        })

      Context.Field.call(character, {:add_field_skill, skill_cast})
    end
  end

  defp damage_targets(skill_cast, crit?, target_count, mobs, packet)
       when target_count > 0 do
    {obj_id, packet} = get_int(packet)
    {_, packet} = get_byte(packet)

    mobs =
      case Managers.FieldNpc.call(:lookup, skill_cast.caster, obj_id) do
        {:ok, %{dead?: false, type: :mob} = mob} ->
          {mob, dmg} = damage_mob(skill_cast, mob, crit?)
          Context.Field.broadcast(skill_cast.caster, Packets.Stats.update_mob_stat(mob, :health))
          mobs ++ [{mob, dmg}]

        _any ->
          mobs
      end

    damage_targets(skill_cast, crit?, target_count - 1, mobs, packet)
  end

  defp damage_targets(_skill_cast, _crit?, _target_count, mobs, _packet), do: mobs

  defp damage_mob(skill_cast, mob, crit?) do
    dmg = Context.Damage.calculate(skill_cast, mob, crit?)

    {:ok, mob} =
      Managers.FieldNpc.call({:inflict_dmg, skill_cast.caster, dmg}, skill_cast.caster, mob)

    # TODO Buff
    # if Types.SkillCast.element_debuff?(skill_cast) or
    #      Types.SkillCast.entity_debuff?(skill_cast) do
    #   status = Types.SkillStatus.new(skill_cast, mob.object_id, skill_cast.caster.object_id, 1)
    #   Context.Field.add_status(skill_cast.caster, status)
    # end

    {mob, dmg}
  end

  defp damage_targets(packet, 0, _skill_cast), do: packet

  defp damage_targets(packet, target_count, skill_cast) do
    Enum.reduce(1..target_count, {[], packet}, fn
      _, {targets, packet} ->
        {uid, packet} = get_long(packet)
        {target_id, packet} = get_int(packet)
        {unknown, packet} = get_byte(packet)

        targets =
          targets ++
            [
              %{
                prev_uid: 0x0,
                uid: uid,
                target_id: target_id,
                unknown: unknown,
                index: 0x0
              }
            ]

        {more, packet} = get_bool(packet)
        {targets, packet} = get_subtargets(packet, more, targets)

        Context.Field.broadcast(
          skill_cast.caster,
          Packets.SkillDamage.target(skill_cast, targets)
        )

        {[], packet}
    end)
  end

  defp get_subtargets(packet, false, targets) do
    {targets, packet}
  end

  defp get_subtargets(packet, true, targets) do
    last = List.last(targets)
    {uid, packet} = get_long(packet)
    {target_id, packet} = get_int(packet)
    {unknown, packet} = get_byte(packet)
    {index, packet} = get_byte(packet)

    targets =
      targets ++
        [
          %{
            prev_uid: last.uid,
            uid: uid,
            target_id: target_id,
            unknown: unknown,
            index: index
          }
        ]

    {more, packet} = get_bool(packet)
    get_subtargets(packet, more, targets)
  end
end
