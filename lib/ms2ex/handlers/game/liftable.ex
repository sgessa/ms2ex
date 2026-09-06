defmodule Ms2ex.GameHandlers.Liftable do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Packets.PacketReader

  @pickup 0x1

  # the player picks a liftable prop up with the interact key
  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    case command do
      command when command == @pickup ->
        {uuid, _packet} = get_string(packet)
        {:ok, character} = Managers.Character.call(session.character_id, :lookup)
        Context.Field.call(character.field_pid, {:pickup_liftable, character.id, uuid})
        session

      _ ->
        session
    end
  end
end
