defmodule Ms2ex.GameHandlers.Taxi do
  alias Ms2ex.{Characters, Field, Packets, Taxi, Wallets, World, WorldGraph}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Car
  def handle_mode(0x1, packet, session) do
    {map_id, _packet} = get_int(packet)
    {:ok, character} = World.get_character(session.character_id)

    case WorldGraph.get_shortest_path(character.map_id, map_id) do
      {:ok, _path, map_count} ->
        cost = Taxi.calc_taxi_cost(map_count, character.level)
        ride_taxi(map_id, :mesos, cost, session)

      :error ->
        session
    end
  end

  # Rotors Mesos
  def handle_mode(0x3, packet, session) do
    {map_id, _packet} = get_int(packet)
    {:ok, character} = World.get_character(session.character_id)
    cost = Taxi.calc_rotor_cost(character.level)
    ride_taxi(map_id, :mesos, cost, session)
  end

  # Rotors Meret
  @rotor_merets_cost -15
  def handle_mode(0x4, packet, session) do
    {map_id, _packet} = get_int(packet)
    ride_taxi(map_id, :merets, @rotor_merets_cost, session)
  end

  # Discover Taxi
  def handle_mode(0x5, _packet, session) do
    {:ok, character} = World.get_character(session.character_id)

    if Enum.member?(character.taxis, character.map_id) do
      session
    else
      taxis = [character.map_id | character.taxis]
      {:ok, character} = Characters.update(character, %{taxis: taxis})
      World.update_character(character)
      push(session, Packets.Taxi.discover(character.map_id))
    end
  end

  def handle_mode(_mode, _packet, session), do: session

  defp ride_taxi(map_id, currency, cost, session) do
    with {:ok, character} <- World.get_character(session.character_id),
         {:ok, wallet} <- Wallets.update(character, currency, cost) do
      session = push(session, Packets.Wallet.update(wallet, currency))
      Field.change_field(character, session, map_id)
    else
      _ ->
        session
    end
  end
end
