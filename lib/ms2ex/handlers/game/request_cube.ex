defmodule Ms2ex.GameHandlers.RequestCube do
  alias Ms2ex.{CharacterManager, Field, Metadata, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Pick up
  def handle_mode(0x11, packet, session) do
    {coord, _packet} = get_sbyte_coord(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, map} <- Metadata.Maps.lookup(character.field_id),
         {:ok, object} <- find_object(map, coord) do
      Field.broadcast(character, Packets.UserBattle.set_stance(character, true))
      push(session, Packets.ResponseCube.pickup(character, object.weapon_id, coord))
    else
      _ -> session
    end
  end

  # Drop
  def handle_mode(0x12, _packet, session) do
    with {:ok, character} <- CharacterManager.lookup(session.character_id) do
      Field.broadcast(character, Packets.UserBattle.set_stance(character, false))
      push(session, Packets.ResponseCube.drop(character))
    else
      _ -> session
    end
  end

  defp find_object(map, coord) do
    case Enum.find(map.objects, &(&1.coord == coord)) do
      nil -> :error
      object -> {:ok, object}
    end
  end
end
