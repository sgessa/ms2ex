defmodule Ms2ex.GameHandlers.Skill do
  require Logger

  alias Ms2ex.{Field, Net, Packets, Registries, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # First Sent
  def handle_mode(0x0, packet, session) do
    {cast_id, packet} = get_long(packet)
    {value, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {skill_level, packet} = get_short(packet)
    {_, packet} = get_byte(packet)
    {coords, _packet} = get_coord(packet)

    skill_cast = %{id: cast_id, skill_id: skill_id, level: skill_level}
    Registries.SkillCasts.set_skill_cast(skill_cast)

    push(session, Packets.Skill.use_skill(skill_cast, value, coords))
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

  defp handle_damage(0x1, packet, session) do
    {cast_id, packet} = get_long(packet)
    {value, packet} = get_int(packet)
    {_char_obj_id, packet} = get_int(packet)

    {:ok, character} = World.get_character(session.world, session.character_id)
    {:ok, skill_cast} = Registries.SkillCasts.get_skill_cast(cast_id)

    {coord, packet} = get_coord(packet)
    {_coord2, packet} = get_coord(packet)
    {_coord3, packet} = get_coord(packet)
    {_, packet} = get_byte(packet)

    {target_count, packet} = get_byte(packet)
    {_, packet} = get_int(packet)

    {target_ids, _packet} = find_targets(packet, target_count)
    Field.damage_mobs(character, skill_cast, value, coord, target_ids)

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
