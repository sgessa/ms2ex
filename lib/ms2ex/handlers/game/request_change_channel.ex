defmodule Ms2ex.GameHandlers.RequestChangeChannel do
  require Logger

  alias Ms2ex.{Net, Packets, Registries}

  import Net.SessionHandler, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {channel_id, _packet} = get_short(packet)

    {:ok, character} = Registries.Characters.lookup(session.character_id)
    {:ok, auth_data} = Registries.Sessions.lookup(session.account.id)
    push(session, Packets.GameToGame.bytes(channel_id, character.map_id, auth_data))
  end
end
