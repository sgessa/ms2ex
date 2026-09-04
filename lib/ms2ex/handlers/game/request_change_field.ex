defmodule Ms2ex.GameHandlers.RequestChangeField do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_change_field(mode, packet, session)
  end

  defp handle_change_field(0x0, packet, session) do
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    {current_map_id, packet} = get_int(packet)

    if current_map_id == character.map_id do
      portals = Storage.Maps.get_portals(current_map_id)
      {src_portal_id, _packet} = get_int(packet)

      case find_portal(portals, src_portal_id) do
        %{target_map_id: dst_map_id} ->
          spawn_point = arrival_point(dst_map_id, current_map_id)

          Context.Field.change_field(
            character,
            dst_map_id,
            spawn_point.position,
            spawn_point.rotation
          )

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  defp handle_change_field(_mode, _packet, _session), do: :ok

  defp find_portal(portals, portal_id) do
    Enum.find(portals, &(&1.id == portal_id))
  end

  # the destination's portal leading back to the current map is the arrival
  # point; maps without a return portal use their default spawn point
  defp arrival_point(dst_map_id, current_map_id) do
    portal =
      dst_map_id
      |> Storage.Maps.get_portals()
      |> Enum.find(&(&1.target_map_id == current_map_id))

    portal || Storage.Maps.get_field_spawn(dst_map_id)
  end
end
