defmodule Ms2ex.GameHandlers.Skill do
  require Logger

  alias Ms2ex.{CharacterManager, Damage, Field, Mob, Net, Packets, SkillCast, SkillStatus}

  import Net.Session, only: [push: 2]
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

    {:ok, character} = CharacterManager.lookup(session.character_id)

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

    {:ok, character} = CharacterManager.cast_skill(character, skill_cast)

    coords = {position, direction, rotation}
    Field.broadcast(character, Packets.Skill.use_skill(skill_cast, coords))

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

    {:ok, character} = CharacterManager.lookup(session.character_id)
    coords = {position, rotation}

    if skill_cast = Agent.get(:"skill_cast:#{cast_id}", & &1) do
      Field.broadcast(
        character,
        Packets.SkillDamage.sync_damage(skill_cast, coords, character, target_count, projectiles)
      )
    end

    session
  end

  defp handle_damage(0x1, packet, session) do
    {cast_id, packet} = get_long(packet)
    {attack_counter, packet} = get_int(packet)
    {_char_obj_id, packet} = get_int(packet)

    {position, packet} = get_coord(packet)
    {impact_pos, packet} = get_coord(packet)
    {rotation, packet} = get_coord(packet)
    {_attack_point, packet} = get_byte(packet)

    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)
    # skill_cast = SkillCast.get(cast_id)

    crit? = Damage.roll_crit(character)
    mobs = damage_targets(session, character, crit?, target_count, [], packet)
    # Field.damage_mobs(character, skill_cast, value, coord, target_ids)

    session
  end

  defp handle_damage(0x2, _packet, session) do
    # {cast_id, packet} = get_long(packet)
    # {_, packet} = get_byte(packet)
    # {_, packet} = get_int(packet)
    # {_, packet} = get_int(packet)
    # {_coord, packet} = get_coord(packet)
    # {_coord2, packet} = get_coord(packet)

    session
  end

  defp damage_targets(session, character, crit?, target_count, mobs, packet)
       when target_count > 0 do
    {obj_id, packet} = get_int(packet)
    {_, packet} = get_byte(packet)

    mobs =
      case Mob.lookup(character, obj_id) do
        {:ok, mob} ->
          {mob, dmg} = damage_mob(character, mob, crit?)
          push(session, Packets.Stats.update_mob_health(mob))
          mobs ++ [{mob, dmg}]

        _ ->
          mobs
      end

    damage_targets(session, character, crit?, target_count - 1, mobs, packet)
  end

  defp damage_targets(_session, _char, _crit?, _target_count, mobs, _packet), do: mobs

  defp damage_mob(character, mob, crit?) do
    skill_cast = character.skill_cast
    dmg = Damage.calculate(character, mob, crit?)
    {:ok, mob} = Mob.inflict_dmg(mob, dmg)

    if SkillCast.element_debuff?(skill_cast) or SkillCast.entity_debuff?(skill_cast) do
      status = SkillStatus.new(skill_cast, mob.object_id, character.object_id, 1)
      Field.add_status(character, status)
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
