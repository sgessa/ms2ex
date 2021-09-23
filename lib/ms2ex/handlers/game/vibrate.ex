defmodule Ms2ex.GameHandlers.Vibrate do
  require Logger

  alias Ms2ex.{CharacterManager, Field, Packets}

  import Packets.PacketReader

  def handle(packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)

    {entity_id, packet} = get_string(packet)
    {some_id, packet} = get_long(packet)
    {obj_id, packet} = get_int(packet)
    {flag, packet} = get_int(packet)
    {_, packet} = get_int(packet)
    {_, packet} = get_int(packet)
    {_, packet} = get_int(packet)
    {_, _packet} = get_int(packet)

    tick = session.client_tick

    Field.broadcast(
      character,
      Packets.Vibrate.bytes(character, entity_id, some_id, obj_id, flag, tick)
    )

    session
  end
end
