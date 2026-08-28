defmodule Ms2ex.GameHandlers.CharacterInfo do
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Ms2ex.Packets.PacketReader, only: [get_long: 1]

  def handle(packet, session) do
    {character_id, _packet} = get_long(packet)

    case Managers.Character.lookup(character_id) do
      {:ok, character} -> push(session, Packets.CharacterInfo.load(character))
      :error -> push(session, Packets.CharacterInfo.not_found(character_id))
    end
  end
end
