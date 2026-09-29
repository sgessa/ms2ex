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

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    # holding an object weapon locks the skill bar to its throw skill; the
    # throw consumes the hold, any other cast is refused
    case Managers.Field.use_liftup_skill(character, skill_id, skill_level) do
      :ok ->
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

        use_cast(
          session,
          character,
          skill_cast,
          {unknown, is_hold, hold_int, hold_string},
          item_uid
        )

      # a held object weapon blocks every skill but its throw
      :error ->
        :error
    end

    session
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

      Managers.Field.broadcast(skill_cast.caster, Packets.SkillSync.bytes(skill_cast))
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
      Managers.Field.broadcast(skill_cast.caster, Packets.SkillCancel.bytes(skill_cast))
    end
  end

  # point attacks are resolved client-side: the caster reports each hit
  # (object id 0 when nothing valid was hit) and the server relays the
  # impact to everyone else, who did not simulate the swing
  # TODO hits with no reported target need server-side detection of
  # hittable corpses in the attack range
  defp handle_damage(@point, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {attack_point, packet} = get_byte(packet)
    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {target_count, packet} = get_byte(packet)
    {_iterations, packet} = get_int(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      skill_cast =
        Managers.SkillCast.update(skill_cast, %{
          position: position,
          direction: direction,
          attack_point: attack_point
        })

      Managers.Field.enter_battle_stance(skill_cast.caster)

      relay_point_hits(skill_cast, target_count, packet)
    end
  end

  defp handle_damage(@target, packet, _session) do
    {cast_id, packet} = get_long(packet)
    {attack_counter, packet} = get_int(packet)
    {_char_obj_id, packet} = get_int(packet)

    {position, packet} = get_coord(packet)
    {_impact_pos, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {attack_point, packet} = get_byte(packet)

    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)

    with {:ok, skill_cast} <- Managers.SkillCast.get(cast_id) do
      skill_cast =
        Managers.SkillCast.update(skill_cast, %{
          position: position,
          direction: direction,
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

      Managers.Field.add_region_skill(skill_cast.caster, skill_cast)
    end
  end

  defp relay_point_hits(_skill_cast, 0, _packet), do: :ok

  defp relay_point_hits(skill_cast, count, packet) do
    {records, packet} = read_point_lead(packet)
    relay_point_hit(skill_cast, records)
    relay_point_hits(skill_cast, count - 1, packet)
  end

  # the lead record of one swing; a same-swing chain follows while the
  # client keeps reporting (each link carries the previous uid + its index)
  defp read_point_lead(packet) do
    {uid, packet} = get_long(packet)
    {target_id, packet} = get_int(packet)
    {unknown, packet} = get_byte(packet)
    {more, packet} = get_bool(packet)

    record = %{prev_uid: 0, uid: uid, target_id: target_id, unknown: unknown, index: 0}
    read_point_chain(packet, more, [record], uid)
  end

  defp read_point_chain(packet, false, records, _prev_uid), do: {records, packet}

  defp read_point_chain(packet, true, records, prev_uid) do
    {uid, packet} = get_long(packet)
    {target_id, packet} = get_int(packet)
    {unknown, packet} = get_byte(packet)
    {index, packet} = get_byte(packet)
    {more, packet} = get_bool(packet)

    record = %{prev_uid: prev_uid, uid: uid, target_id: target_id, unknown: unknown, index: index}
    read_point_chain(packet, more, records ++ [record], uid)
  end

  defp relay_point_hit(skill_cast, records) do
    Managers.Field.broadcast_from(
      skill_cast.caster,
      Packets.SkillDamage.target(skill_cast, records),
      self()
    )
  end

  # damage numbers (mode 1) for server-applied target hits
  defp broadcast_damage(_skill_cast, []), do: :ok

  defp broadcast_damage(skill_cast, mobs) do
    Managers.Field.broadcast(skill_cast.caster, Packets.SkillDamage.damage(skill_cast, mobs))
  end

  defp damage_targets(skill_cast, crit?, target_count, mobs, packet)
       when target_count > 0 do
    {obj_id, packet} = get_int(packet)
    {_, packet} = get_byte(packet)

    mobs =
      case Managers.Field.lookup_npc(skill_cast.caster, obj_id) do
        {:ok, %{dead?: false, type: :mob} = mob} ->
          {mob, dmg} = damage_mob(skill_cast, mob, crit?)
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
      Managers.Field.inflict_dmg(skill_cast.caster, dmg, mob.object_id)

    Managers.PartyServer.record_damage(skill_cast.caster, dmg.dmg)

    # on-hit effects (e.g. Flame Wave's burn) apply to the target
    Managers.Field.apply_skill_effects(skill_cast.caster, skill_cast, mob.object_id)

    # TODO Buff
    # if Types.SkillCast.element_debuff?(skill_cast) or
    #      Types.SkillCast.entity_debuff?(skill_cast) do
    #   status = Types.SkillStatus.new(skill_cast, mob.object_id, skill_cast.caster.object_id, 1)
    #   Managers.Field.add_status(skill_cast.caster, status)
    # end

    {mob, dmg}
  end

  defp use_cast(session, character, skill_cast, state, item_uid) do
    {:ok, character} = Managers.Character.call(character, {:cast_skill, skill_cast})

    cast_item = cast_item(character, item_uid)

    consumable_cast_item? =
      fishing_lure_item?(cast_item) or consumable_state_item?(cast_item)

    if Types.SkillCast.use_item?(skill_cast) do
      consume_used_item(session, character, item_uid)
    end

    case Types.SkillCast.cooldown(skill_cast, Ms2ex.sync_ticks()) do
      nil ->
        :ok

      cooldown ->
        Managers.Character.call(character, {:save_skill_cooldown, cooldown})
        push(session, Packets.SkillCooldown.bytes([cooldown]))
    end

    use_packet = Packets.SkillUse.bytes(skill_cast, state)

    # battle-start sequence in the order live servers emit it:
    # skill use, battle flag, full stat refresh, casting actor state
    Managers.Field.broadcast(character, use_packet)

    if Types.SkillCast.in_battle?(skill_cast) do
      Managers.Field.broadcast(character, Packets.UserBattle.set_stance(character, true))
    end

    Managers.Field.broadcast_stats(character)
    Managers.Field.broadcast(character, Packets.ProxyGameObj.update_state(character, 16))

    if consumable_cast_item? do
      consume_used_item(session, character, item_uid)
    end

    # skill-use quest conditions track casts per skill id
    Managers.Quest.update_conditions(
      character.id,
      :skill,
      1,
      "",
      character.map_id,
      "",
      skill_cast.skill_id
    )
  end

  defp consume_used_item(session, character, item_uid) do
    case Managers.Inventory.get(character, item_uid) do
      %Ms2ex.Schema.Item{} = item ->
        consumed_item = Managers.Inventory.consume(item)
        push(session, Packets.InventoryItem.consume(consumed_item))

      _ ->
        :ok
    end
  end

  # the cast item, with its metadata loaded; nil when the cast references no
  # inventory item
  defp cast_item(_character, 0), do: nil

  defp cast_item(character, item_uid) do
    case Managers.Inventory.get(character, item_uid) do
      %Ms2ex.Schema.Item{} = item ->
        Context.Items.load_metadata(item)

      _ ->
        nil
    end
  end

  defp fishing_lure_item?(%Ms2ex.Schema.Item{metadata: %{property: %{tag: :fishing_lure}}}),
    do: true

  defp fishing_lure_item?(_item), do: false

  # a skill item whose cast toggles a client convenience state (the
  # auto-fishing and auto-performance vouchers) is consumed by its own cast
  defp consumable_state_item?(%Ms2ex.Schema.Item{} = item) do
    Context.Items.state_effects(item.metadata) != []
  end

  defp consumable_state_item?(nil), do: false
end
