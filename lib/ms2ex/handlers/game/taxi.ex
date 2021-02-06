defmodule Ms2ex.GameHandlers.Taxi do
  alias Ms2ex.{Field, Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Car
  def handle_mode(0x1, packet, session) do
    ride_taxi_with_mesos(packet, session)
  end

  # Rotors Mesos
  def handle_mode(0x3, packet, session) do
    ride_taxi_with_mesos(packet, session)
  end

  # Rotors Meret
  # @rotor_merets_cost 15
  def handle_mode(0x4, packet, session) do
    {map_id, _packet} = get_int(packet)
    {:ok, character} = World.get_character(session.world, session.character_id)
    Field.change_field(character, session, map_id)
  end

  # Discover Taxi
  def handle_mode(0x5, _packet, session) do
    {:ok, character} = World.get_character(session.world, session.character_id)
    push(session, Packets.Taxi.discover(character.map_id))
  end

  def handle_mode(_mode, _packet, session), do: session

  # @taxi_mesos_cost 5000
  defp ride_taxi_with_mesos(packet, session) do
    {map_id, _packet} = get_int(packet)
    {:ok, character} = World.get_character(session.world, session.character_id)
    Field.change_field(character, session, map_id)
  end
end
