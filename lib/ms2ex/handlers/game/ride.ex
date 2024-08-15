defmodule Ms2ex.GameHandlers.Ride do
  require Logger

  alias Ms2ex.{Managers, Context, Packets}

  import Packets.PacketReader

  @start 0x00
  @stop 0x01
  @change 0x02
  # @join 0x03
  # @leave 0x04

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  defp handle_mode(@start, packet, session) do
    {type, packet} = get_byte(packet)
    {ride_id, packet} = get_int(packet)
    {_object_id, packet} = get_int(packet)
    {_item_id, packet} = get_int(packet)

    {item_uid, _packet} = get_long(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    # TODO check if the user owns this mount
    item = Context.Inventory.get(character, item_uid)

    mount = %{
      character_id: character.id,
      item_id: item.item_id,
      item_uid: item.id,
      mount_type: type,
      ride_id: ride_id
    }

    # TODO: We don't need to add mount to the field, we can use a global object id
    {:ok, mount} = Context.Field.call(character.field_pid, {:add_mount, mount})

    Context.Field.broadcast(character, Packets.ResponseRide.start_ride(character, mount))
  end

  defp handle_mode(@stop, packet, session) do
    {_, packet} = get_byte(packet)
    {forced, _packet} = get_bool(packet)
    {:ok, character} = Managers.Character.lookup(session.character_id)
    Context.Field.broadcast(character, Packets.ResponseRide.stop_ride(character, forced))
  end

  defp handle_mode(@change, packet, session) do
    {item_id, packet} = get_int(packet)
    {id, _packet} = get_long(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)
    Context.Field.broadcast(character, Packets.ResponseRide.change_ride(character, item_id, id))
  end

  defp handle_mode(_mode, _packet, session) do
    session
  end
end
