defmodule Ms2ex.GameHandlers.Skill do
  require Logger

  alias Ms2ex.{Managers, Context, Net, Packets, SkillCast, Types}
  alias Ms2ex.Managers

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Cast
  def handle_mode(0x0, packet, session) do
    {cast_id, packet} = get_long(packet)
    {server_tick, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {skill_lvl, packet} = get_short(packet)
    {attack_point, packet} = get_byte(packet)

    {position, packet} = get_coord(packet)
    {direction, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)

    {_, packet} = get_float(packet)

    {client_tick, packet} = get_int(packet)

    {_, packet} = get_bool(packet)
    {_, packet} = get_bool(packet)
    {_flag, _packet} = get_bool(packet)

    # if (flag) {
    #   packet.ReadInt()
    #   string unkString = packet.ReadUnicodeString()
    # }

    {:ok, character} = Managers.Character.lookup(session.character_id)

    skill_cast =
      SkillCast.build(
        cast_id,
        character.object_id,
        skill_id,
        skill_lvl,
        attack_point,
        server_tick,
        client_tick
      )

    SkillCast.start(skill_cast)

    {:ok, character} = Managers.Character.cast_skill(character, skill_cast)

    coords = {position, direction, rotation}
    Context.Field.broadcast(character, Packets.Skill.use_skill(skill_cast, coords))

    push(session, Packets.Stats.set_character_stats(character))
  end

  # Damage Mode
  def handle_mode(0x1, packet, session) do
    {damage_type, packet} = get_byte(packet)
    handle_damage(damage_type, packet, session)
  end

  def handle_mode(_mode, _packet, session), do: session

  # Sync Damage
  defp handle_damage(0x0, packet, session) do
    {cast_id, packet} = get_long(packet)
    {_attack_point, packet} = get_byte(packet)
    {position, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)
    {projectiles, _packet} = get_projectiles(packet, target_count)

    {:ok, character} = Managers.Character.lookup(session.character_id)
    coords = {position, rotation}

    if skill_cast = Agent.get(:"skill_cast:#{cast_id}", & &1) do
      Context.Field.broadcast(
        character,
        Packets.SkillDamage.sync_damage(skill_cast, coords, character, target_count, projectiles)
      )
    end
  end

  # Damage
  defp handle_damage(0x1, packet, session) do
    {cast_id, packet} = get_long(packet)
    {attack_counter, packet} = get_int(packet)
    {_char_obj_id, packet} = get_int(packet)

    {position, packet} = get_coord(packet)
    {_impact_pos, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {_attack_point, packet} = get_byte(packet)

    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    # TODO: skill_cast.id == cast_id doesn't always matches
    # targeting won't work randomly

    if character.skill_cast.id == cast_id do
      crit? = Context.Damage.roll_crit(character)
      mobs = damage_targets(session, character, crit?, target_count, [], packet)

      # TODO check whether it's a player or an ally
      if SkillCast.heal?(character.skill_cast) do
        status =
          Types.SkillStatus.new(character.skill_cast, character.object_id, character.object_id, 1)

        Context.Field.add_status(character, status)

        # TODO heal based on stats
        heal = 50
        Context.Field.broadcast(character, Packets.SkillDamage.heal(status, heal))

        {:ok, character} = Managers.Character.increase_stat(character, :hp, heal)
        push(session, Packets.Stats.update_char_stats(character, :hp))
      else
        coords = {position, rotation}

        Context.Field.broadcast(
          character,
          Packets.SkillDamage.damage(character, mobs, coords, attack_counter)
        )
      end
    end
  end

  # AoE Damage
  defp handle_damage(0x2, packet, session) do
    {cast_id, packet} = get_long(packet)
    {_mode, packet} = get_byte(packet)
    {_, packet} = get_int(packet)
    {_, packet} = get_int(packet)
    {_position, packet} = get_coord(packet)
    {_rotation, _packet} = get_coord(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    if character.skill_cast.id == cast_id do
      conditions =
        character.skill_cast |> SkillCast.condition_skills() |> Enum.filter(& &1.splash)

      for s <- conditions do
        skill_cast = SkillCast.build(s.id, s.level, character.skill_cast, session.server_tick)
        Context.Field.add_region_skill(character, skill_cast)
      end
    end
  end

  defp damage_targets(session, character, crit?, target_count, mobs, packet)
       when target_count > 0 do
    {obj_id, packet} = get_int(packet)
    {_, packet} = get_byte(packet)

    mobs =
      case Managers.FieldNpc.call(:lookup, character, obj_id) do
        {:ok, %{dead?: false, type: :mob} = mob} ->
          {mob, dmg} = damage_mob(character, mob, crit?)
          Context.Field.broadcast(character, Packets.Stats.update_mob_stat(mob, :health))
          mobs ++ [{mob, dmg}]

        _any ->
          mobs
      end

    damage_targets(session, character, crit?, target_count - 1, mobs, packet)
  end

  defp damage_targets(_session, _char, _crit?, _target_count, mobs, _packet), do: mobs

  defp damage_mob(character, mob, crit?) do
    skill_cast = character.skill_cast
    dmg = Context.Damage.calculate(character, mob, crit?)
    {:ok, mob} = Managers.FieldNpc.call({:inflict_dmg, character, dmg}, character, mob)

    if SkillCast.element_debuff?(skill_cast) or SkillCast.entity_debuff?(skill_cast) do
      status = Types.SkillStatus.new(skill_cast, mob.object_id, character.object_id, 1)
      Context.Field.add_status(character, status)
    end

    {mob, dmg}
  end

  defp get_projectiles(packet, target_count) do
    projectiles = %{
      attk_count: [],
      source_ids: [],
      target_ids: [],
      animations: []
    }

    Enum.reduce(0..target_count, {projectiles, packet}, fn
      0, acc ->
        acc

      _, {projectiles, packet} ->
        {attk_count, packet} = get_int(packet)
        {source_id, packet} = get_int(packet)
        {target_id, packet} = get_int(packet)
        {animation, packet} = get_short(packet)

        projectiles = %{
          attk_count: projectiles.attk_count ++ [attk_count],
          source_ids: projectiles.source_ids ++ [source_id],
          target_ids: projectiles.target_ids ++ [target_id],
          animations: projectiles.animations ++ [animation]
        }

        {projectiles, packet}
    end)
  end
end
