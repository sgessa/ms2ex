defmodule Ms2ex.GameHandlers.Taxi do
  alias Ms2ex.{Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Discover Taxi
  def handle_mode(0x5, _packet, session) do
    {:ok, character} = World.get_character(session.world, session.character_id)
    push(session, Packets.Taxi.discover(character.map_id))
  end

  def handle_mode(_mode, _packet, session), do: session
end
