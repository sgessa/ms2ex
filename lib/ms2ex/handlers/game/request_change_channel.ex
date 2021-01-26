defmodule Ms2ex.GameHandlers.RequestChangeChannel do
  require Logger

  alias Ms2ex.{Net, Packets}

  import Net.SessionHandler, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {channel_id, _packet} = get_short(packet)

    {:ok, session_data} = Net.SessionRegistry.lookup(session.account.id)
    push(session, Packets.GameToGame.bytes(channel_id, session.character.map_id, session_data))
  end
end
