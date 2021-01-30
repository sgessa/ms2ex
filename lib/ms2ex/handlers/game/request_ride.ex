defmodule Ms2ex.GameHandlers.RequestRide do
  require Logger

  alias Ms2ex.{Field, Packets, Registries}

  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_ride(mode, packet, session)
  end

  # Start Ride
  defp handle_ride(0x0, packet, session) do
    {type, packet} = get_byte(packet)
    {item_id, packet} = get_int(packet)
    {_, packet} = get_long(packet)

    # TODO check if the user owns this mount
    {id, _packet} = get_long(packet)

    {:ok, character} = Registries.Characters.lookup(session.character_id)
    {:ok, object_id} = Field.request_object_id(character)

    mount = %{type: type, item_id: item_id, id: id, object_id: object_id}
    Field.broadcast(character, Packets.ResponseRide.start_ride(character, mount))

    session
  end

  # Stop Ride
  defp handle_ride(0x1, packet, session) do
    {_, packet} = get_byte(packet)
    {forced, _packet} = get_bool(packet)
    {:ok, character} = Registries.Characters.lookup(session.character_id)
    Field.broadcast(character, Packets.ResponseRide.stop_ride(character, forced))
    session
  end

  defp handle_ride(_mode, _packet, session) do
    session
  end
end
