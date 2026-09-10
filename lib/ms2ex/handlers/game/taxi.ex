defmodule Ms2ex.GameHandlers.Taxi do
  require Logger

  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Car
  def handle_mode(0x1, packet, session) do
    {map_id, _packet} = get_int(packet)
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    case Context.WorldGraph.get_shortest_path(character.map_id, map_id) do
      {:ok, _path, map_count} ->
        cost = Context.Taxi.calc_taxi_cost(map_count, character.level)
        ride_taxi(map_id, :mesos, cost, session)

      :error ->
        :ok
    end
  end

  # Rotors Mesos
  def handle_mode(0x3, packet, session) do
    {map_id, _packet} = get_int(packet)
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)
    cost = Context.Taxi.calc_rotor_cost(character.level)
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
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    if Enum.member?(character.taxis, character.map_id) do
      :ok
    else
      taxis = [character.map_id | character.taxis]
      {:ok, character} = Context.Characters.update(character, %{taxis: taxis})
      Managers.Character.call(character, {:update, character})
      push(session, Packets.Taxi.discover(character.map_id))
    end
  end

  def handle_mode(_mode, _packet, _session), do: :ok

  defp ride_taxi(map_id, currency, cost, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, _wallet} <- charge_taxi(character, currency, cost) do
      Managers.Quest.update_conditions(character.id, :taxiuse)

      case Managers.Field.change_field(character, map_id) do
        :ok -> :ok
        error -> Logger.warning("Taxi field change to #{map_id} failed: #{inspect(error)}")
      end
    end
  end

  defp charge_taxi(character, :mesos, cost) do
    if Context.PremiumMemberships.active?(character.account_id) do
      {:ok, Context.Wallets.find(character)}
    else
      Context.Wallets.update(character, :mesos, -cost)
    end
  end

  defp charge_taxi(character, currency, cost),
    do: Context.Wallets.update(character, currency, cost)
end
