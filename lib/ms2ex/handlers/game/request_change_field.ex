defmodule Ms2ex.GameHandlers.RequestChangeField do
  require Logger

  alias Ms2ex.{Managers, Context, Packets, Storage}

  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_change_field(mode, packet, session)
  end

  defp handle_change_field(0x0, packet, session) do
    {:ok, character} = Managers.Character.lookup(session.character_id)

    {current_map_id, packet} = get_int(packet)

    with true <- current_map_id == character.map_id,
         portals <- Storage.Maps.get_portals(current_map_id),
         {src_portal_id, _packet} = get_int(packet),
         %{target_map_id: dst_map_id} <- find_portal(portals, src_portal_id),
         dst_map_portals <- Storage.Maps.get_portals(dst_map_id),
         spawn_point <- find_spawn_point(dst_map_portals, current_map_id) do
      Context.Field.change_field(
        character,
        dst_map_id,
        spawn_point.position,
        spawn_point.rotation
      )
    end
  end

  defp handle_change_field(_mode, _packet, session), do: session

  defp find_portal(portals, portal_id) do
    Enum.find(portals, &(&1.id == portal_id))
  end

  defp find_spawn_point(portals, map_id) do
    Enum.find(portals, &(&1.target_map_id == map_id))
  end
end
