defmodule Ms2ex.GameHandlers.RequestChangeChannel do
  require Logger

  alias Ms2ex.{Net, Packets, Sessions, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {channel_id, _packet} = get_short(packet)

    # TODO check channel_id is valid

    {:ok, character} = World.get_character(session.character_id)
    {:ok, auth_data} = Sessions.lookup(session.account.id)

    World.update_character(Map.put(character, :channel_id, channel_id))

    push(session, Packets.GameToGame.bytes(channel_id, character.map_id, auth_data))
  end
end
