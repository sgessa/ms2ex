defmodule Ms2ex.GameHandlers.Skill do
  require Logger

  alias Ms2ex.{Field, Net, Packets, SkillCast, SkillCasts, StatsManager, World}

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
    #   packet.ReadInt();
    #   string unkString = packet.ReadUnicodeString();
    # }

    {:ok, character} = World.get_character(session.character_id)

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

    character = SkillCasts.cast(character, skill_cast)
    World.update_character(character)

    coords = {position, direction, rotation}
    Field.broadcast(character, Packets.Skill.use_skill(skill_cast, coords))

    {:ok, stats} = StatsManager.lookup(character)
    push(session, Packets.Stats.set_character_stats(%{character | stats: stats}))
  end

  # Damage
  def handle_mode(0x1, packet, session) do
    {damage_type, packet} = get_byte(packet)
    handle_damage(damage_type, packet, session)
  end

  def handle_mode(_mode, _packet, session), do: session

  defp handle_damage(0x0, _packet, session) do
    # {cast_id, packet} = get_long(packet)
    # {value, packet} = get_byte(packet)
    # {coord, packet} = get_coord(packet)
    # {_coord2, packet} = get_coord(packet)
    # {target_count, packet} = get_byte(packet)
    # {_, packet} = get_int(packet)

    session
  end

  defp handle_damage(0x1, _packet, session) do
    # {cast_id, packet} = get_long(packet)
    # {value, packet} = get_int(packet)
    # {_char_obj_id, packet} = get_int(packet)

    # {:ok, character} = World.get_character(session.character_id)
    # {:ok, skill_cast} = Registries.SkillCasts.get_skill_cast(cast_id)

    # {coord, packet} = get_coord(packet)
    # {_coord2, packet} = get_coord(packet)
    # {_coord3, packet} = get_coord(packet)
    # {_, packet} = get_byte(packet)

    # {target_count, packet} = get_byte(packet)
    # {_, packet} = get_int(packet)

    # {target_ids, _packet} = find_targets(packet, target_count)
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

  def find_targets(packet, count) do
    Enum.reduce(0..count, {[], packet}, fn
      0, acc ->
        acc

      _, {targets, packet} ->
        {obj_id, packet} = get_int(packet)
        {_, packet} = get_byte(packet)
        {[obj_id | targets], packet}
    end)
  end
end
