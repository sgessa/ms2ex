defmodule Ms2ex.GameHandlers.RequestChangeField do
  require Logger

  alias Ms2ex.{Field, Metadata, Net, Packets, Registries}

  import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

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
      :ok = Field.leave(character)

      new_map = %{id: dst_map.id, position: dst_portal.coord, rotation: dst_portal.rotation}

      character
      |> Map.put(:change_map, new_map)
      |> Registries.Characters.update()

      session
      |> push(Packets.RequestFieldEnter.bytes(new_map.id, new_map.position, new_map.rotation))
    else
      _ ->
        session
    end
  end

  defp handle_change_field(_mode, _packet, session), do: session
end
