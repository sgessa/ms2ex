defmodule Ms2ex.GameHandlers.Taxi do
  alias Ms2ex.{Characters, CharacterManager, Field, Packets, Taxi, Wallets, WorldGraph}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Car
  def handle_mode(0x1, packet, session) do
    {field_id, _packet} = get_int(packet)
    {:ok, character} = CharacterManager.lookup(session.character_id)

    case WorldGraph.get_shortest_path(character.field_id, field_id) do
      {:ok, _path, map_count} ->
        cost = Taxi.calc_taxi_cost(map_count, character.level)
        ride_taxi(field_id, :mesos, cost, session)

      :error ->
        session
    end
  end

  # Rotors Mesos
  def handle_mode(0x3, packet, session) do
    {field_id, _packet} = get_int(packet)
    {:ok, character} = CharacterManager.lookup(session.character_id)
    cost = Taxi.calc_rotor_cost(character.level)
    ride_taxi(field_id, :mesos, cost, session)
  end

  # Rotors Meret
  @rotor_merets_cost -15
  def handle_mode(0x4, packet, session) do
    {field_id, _packet} = get_int(packet)
    ride_taxi(field_id, :merets, @rotor_merets_cost, session)
  end

  # Discover Taxi
  def handle_mode(0x5, _packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)

    if Enum.member?(character.taxis, character.field_id) do
      session
    else
      taxis = [character.field_id | character.taxis]
      {:ok, character} = Characters.update(character, %{taxis: taxis})
      CharacterManager.update(character)
      push(session, Packets.Taxi.discover(character.field_id))
    end
  end

  def handle_mode(_mode, _packet, session), do: session

  defp ride_taxi(field_id, currency, cost, session) do
    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, _wallet} <- Wallets.update(character, currency, cost) do
      Field.change_field(character, field_id)
    end
  end
end
