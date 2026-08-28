defmodule Ms2ex.GameHandlers.Skill do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

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

    {client_tick, packet} = get_int(packet)

    {unknown, packet} = get_bool(packet)
    {item_uid, packet} = get_long(packet)
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
        client_tick: client_tick,
        item_uid: item_uid
      })

    {:ok, character} = Managers.Character.call(character, {:cast_skill, skill_cast})

    if Types.SkillCast.use_item?(skill_cast) do
      consume_used_item(session, character, item_uid)
    end

    case Types.SkillCast.cooldown(skill_cast, Ms2ex.sync_ticks()) do
      nil -> :ok
      cooldown -> Managers.Character.save_skill_cooldown(character, cooldown)
    end

    state = {unknown, is_hold, hold_int, hold_string}
    use_packet = Packets.SkillUse.bytes(skill_cast, state)

    # battle-start sequence in the order live servers emit it:
    # skill use, battle flag, skill use relay, full stat refresh,
    # casting actor state
    Context.Field.broadcast(character, use_packet)

    if Types.SkillCast.in_battle?(skill_cast) do
      Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, true))
    end

    Context.Field.broadcast(character, use_packet)
    Context.Field.broadcast_stats(character)
    Context.Field.broadcast(character, Packets.ProxyGameObj.update_state(character, 16))
  end

  def handle_mode(@attack, packet, session) do
    {damage_type, packet} = get_byte(packet)
    handle_damage(damage_type, packet, session)
  end

  def handle_mode(@sync, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {_skill_id, packet} = get_int(packet)
    {_skill_level, packet} = get_short(packet)
    {motion_point, packet} = get_byte(packet)

    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {_input, packet} = get_coord(packet)
    {_toggle, packet} = get_byte(packet)
    {_is_release, packet} = get_byte(packet)
    {_unk3, _packet} = get_int(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      Managers.SkillCast.update(skill_cast, %{
        motion_point: motion_point,
        position: position,
        direction: direction,
        rotation: rotation
      })

      Context.Field.broadcast(skill_cast.caster, Packets.SkillSync.bytes(skill_cast))
    end
  end

  def handle_mode(@tick_sync, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {server_tick, _packet} = get_int(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      Managers.SkillCast.update(skill_cast, %{
        server_tick: server_tick
      })
    end
  end

  def handle_mode(@cancel, packet, _session) do
    {cast_id, _packet} = get_long(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      Context.Field.broadcast(skill_cast.caster, Packets.SkillCancel.bytes(skill_cast))
    end
  end

  defp handle_damage(@point, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {attack_point, packet} = get_byte(packet)
    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {_target_count, packet} = get_byte(packet)
    {_iterations, _packet} = get_int(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      Managers.SkillCast.update(skill_cast, %{
        position: position,
        direction: direction,
        attack_point: attack_point
      })
    end
  end

  defp handle_damage(@target, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {attack_counter, packet} = get_int(packet)
    {_char_obj_id, packet} = get_int(packet)

    {position, packet} = get_coord(packet)
    {_impact_pos, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {attack_point, packet} = get_byte(packet)

    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      skill_cast =
        Managers.SkillCast.update(skill_cast, %{
          position: position,
          rotation: rotation,
          attack_counter: attack_counter,
          attack_point: attack_point
        })

      crit? = Context.Damage.roll_crit(skill_cast.caster)

      mobs = damage_targets(skill_cast, crit?, target_count, [], packet)
      broadcast_damage(skill_cast, mobs)

      # TODO
    end
  end

  # AoE Damage
  defp handle_damage(@splash, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {attack_point, packet} = get_byte(packet)
    {_, packet} = get_int(packet)
    {_, packet} = get_int(packet)
    {position, packet} = get_coord(packet)
    {rotation, _packet} = get_coord(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      skill_cast =
        Managers.SkillCast.update(skill_cast, %{
          attack_point: attack_point,
          position: position,
          rotation: rotation
        })

      Context.Field.add_region_skill(skill_cast.caster, skill_cast)
    end
  end

  # the target relay (mode 0) announces which entity was hit and precedes the
  # damage numbers (mode 1)
  defp broadcast_damage(_skill_cast, []), do: :ok

  defp broadcast_damage(skill_cast, mobs) do
    targets =
      mobs
      |> Enum.with_index()
      |> Enum.map(fn {{mob, _dmg}, index} ->
        %{
          prev_uid: 0x0,
          uid: skill_cast.caster.object_id * 0x1_0000_0000 + index,
          target_id: mob.object_id,
          unknown: 0x0,
          index: index
        }
      end)

    Context.Field.broadcast(skill_cast.caster, Packets.SkillDamage.target(skill_cast, targets))
    Context.Field.broadcast(skill_cast.caster, Packets.SkillDamage.damage(skill_cast, mobs))
  end

  defp damage_targets(skill_cast, crit?, target_count, mobs, packet)
       when target_count > 0 do
    {obj_id, packet} = get_int(packet)
    {_, packet} = get_byte(packet)

    mobs =
      case Context.Field.lookup_npc(skill_cast.caster, obj_id) do
        {:ok, %{dead?: false, type: :mob} = mob} ->
          {mob, dmg} = damage_mob(skill_cast, mob, crit?)
          Context.Field.broadcast(skill_cast.caster, Packets.Stats.update_mob_stat(mob, :health))
          mobs ++ [{mob, dmg}]

        _ ->
          mobs
      end

    damage_targets(skill_cast, crit?, target_count - 1, mobs, packet)
  end

  defp damage_targets(_skill_cast, _crit?, _target_count, mobs, _packet), do: mobs

  defp damage_mob(skill_cast, mob, crit?) do
    dmg = Context.Damage.calculate(skill_cast, mob, crit?)

    {:ok, mob} =
      Context.Field.call(skill_cast.caster, {:inflict_dmg, skill_cast.caster, dmg, mob.object_id})

    # on-hit effects (e.g. Flame Wave's burn) apply to the target
    Context.Field.call(skill_cast.caster, {:apply_skill_effects, skill_cast, mob.object_id})

    # TODO Buff
    # if Types.SkillCast.element_debuff?(skill_cast) or
    #      Types.SkillCast.entity_debuff?(skill_cast) do
    #   status = Types.SkillStatus.new(skill_cast, mob.object_id, skill_cast.caster.object_id, 1)
    #   Context.Field.add_status(skill_cast.caster, status)
    # end

    {mob, dmg}
  end

  defp consume_used_item(session, character, item_uid) do
    case Context.Inventory.get(character, item_uid) do
      %Ms2ex.Schema.Item{} = item ->
        consumed_item = Context.Inventory.consume(item)
        push(session, Packets.InventoryItem.consume(consumed_item))

      _ ->
        session
    end
  end
end
