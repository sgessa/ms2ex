defmodule Ms2ex.GameHandlers.RequestChangeField do
  require Logger

  alias Ms2ex.{Field, Metadata, Packets, Registries}

  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_change_field(mode, packet, session)
  end

  defp handle_change_field(0x0, packet, session) do
    {:ok, character} = Registries.Characters.lookup(session.character_id)

    {src_map_id, packet} = get_int(packet)

    with true <- src_map_id == character.map_id,
         {:ok, src_map} <- Metadata.Maps.lookup(src_map_id),
         {src_portal_id, _packet} = get_int(packet),
         %Metadata.MapPortal{} = src_portal <-
           Enum.find(src_map.portals, &(&1.id == src_portal_id)),
         {:ok, dst_map} <- Metadata.Maps.lookup(src_portal.target),
         %Metadata.MapPortal{} = dst_portal <-
           Enum.find(dst_map.portals, &(&1.target == src_map_id)) do
      Field.change_field(character, session, dst_map.id, dst_portal.coord, dst_portal.rotation)
    else
      _ ->
        session
    end
  end

  defp handle_change_field(_mode, _packet, session), do: session
end
