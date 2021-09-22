defmodule Ms2ex.GameHandlers.RequestCube do
  alias Ms2ex.{Metadata, Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Pick up
  def handle_mode(0x11, packet, session) do
    {coord, _packet} = get_sbyte_coord(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         {:ok, map} <- Metadata.Maps.lookup(character.map_id),
         {:ok, object} <- find_object(map, coord) do
      session
      |> push(Packets.ResponseCube.pickup(character, object.weapon_id, coord))
      |> push(Packets.UserBattle.set_stance(character, true))
    else
      _ -> session
    end
  end

  # Drop
  def handle_mode(0x12, _packet, session) do
    with {:ok, character} <- World.get_character(session.character_id) do
      session
      |> push(Packets.ResponseCube.drop(character))
      |> push(Packets.UserBattle.set_stance(character, false))
    else
      _ -> session
    end
  end

  defp find_object(map, coord) do
    IO.inspect(map.objects, label: "OBJ")
    IO.inspect(coord, label: "COORD")

    case Enum.find(map.objects, &(&1.coord == coord)) do
      nil -> :error
      object -> {:ok, object}
    end
  end
end
