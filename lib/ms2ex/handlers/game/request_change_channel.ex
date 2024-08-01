defmodule Ms2ex.GameHandlers.RequestChangeChannel do
  require Logger

  alias Ms2ex.{CharacterManager, Net, Packets, SessionManager}

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {channel_id, _packet} = get_short(packet)

    # TODO check channel_id is valid

    {:ok, character} = CharacterManager.lookup(session.character_id)
    {:ok, auth_data} = SessionManager.lookup(session.account.id)

    CharacterManager.update(Map.put(character, :channel_id, channel_id))

    push(session, Packets.GameToGame.bytes(channel_id, character.map_id, auth_data))
  end
end
