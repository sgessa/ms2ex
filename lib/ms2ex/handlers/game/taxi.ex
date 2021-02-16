defmodule Ms2ex.GameHandlers.Taxi do
  alias Ms2ex.{Field, Packets, Wallets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Car
  # TODO calculate taxi cost
  @taxi_mesos_cost -1000
  def handle_mode(0x1, packet, session) do
    {map_id, _packet} = get_int(packet)
    ride_taxi(map_id, :mesos, @taxi_mesos_cost, session)
  end

  # Rotors Mesos
  @rotor_mesos_cost -60_000
  def handle_mode(0x3, packet, session) do
    {map_id, _packet} = get_int(packet)
    ride_taxi(map_id, :mesos, @rotor_mesos_cost, session)
  end

  # Rotors Meret
  @rotor_merets_cost -15
  def handle_mode(0x4, packet, session) do
    {map_id, _packet} = get_int(packet)
    ride_taxi(map_id, :merets, @rotor_merets_cost, session)
  end

  # Discover Taxi
  def handle_mode(0x5, _packet, session) do
    {:ok, character} = World.get_character(session.world, session.character_id)
    push(session, Packets.Taxi.discover(character.map_id))
  end

  def handle_mode(_mode, _packet, session), do: session

  defp ride_taxi(map_id, currency, cost, session) do
    with {:ok, character} <- World.get_character(session.world, session.character_id),
         {:ok, wallet} <- Wallets.update(character, currency, cost) do
      session = push(session, Packets.Wallet.update(wallet, currency))
      Field.change_field(character, session, map_id)
    else
      _ ->
        session
    end
  end
end
