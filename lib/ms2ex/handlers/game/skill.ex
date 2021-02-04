defmodule Ms2ex.GameHandlers.Skill do
  require Logger

  alias Ms2ex.{Field, Packets, World}

  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # First Sent
  def handle_mode(0x0, packet, session) do
    {:ok, character} = World.get_character(session.world, session.character_id)

    {id, packet} = get_long(packet)
    {value, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {skill_level, packet} = get_short(packet)
    {_, packet} = get_byte(packet)
    {coords, _packet} = get_coord(packet)

    skill_cast = %{id: id, value: value, skill_id: skill_id, level: skill_level}
    Field.broadcast(character, Packets.Skill.use_skill(skill_cast, coords))

    session
  end

  # Damage
  def handle_mode(0x1, _packet, session) do
    # {damage_type, packet} = get_byte(packet)
    # handle_damage(damage_type, packet, session)
    session
  end

  def handle_mode(_mode, _packet, session), do: session

  # defp handle_damage(0x0, packet, session) do
  # {skill_uid, packet} = get_long(packet)
  # {_, packet} = get_byte(packet)
  # {coords, packet} = get_coord(packet)
  # {coords2, packet} = get_coord(packet)
  # {count, packet} = get_byte(packet)
  # {_, packet} = get_int(packet)

  # Enum.reduce(0..count, packet, fn
  #   0, packet ->
  #     packet

  #   _, packet ->
  #     {_, packet} = get_long(packet)
  #     {_, packet} = get_int(packet)
  #     {_, packet} = get_byte(packet)
  #     {bool, packet} = get_bool(packet)

  #     if bool do
  #       {_, packet} = get_long(packet)
  #       packet
  #     else
  #       packet
  #     end
  # end)
  # end
end
