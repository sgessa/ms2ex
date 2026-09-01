defmodule Ms2ex.GameHandlers.RequestChangeChannel do
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Managers.Session

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {channel_id, _packet} = get_short(packet)

    # TODO check channel_id is valid

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)
    {:ok, auth_data} = Session.lookup(session.account.id)

    Managers.Character.call(character, {:update, Map.put(character, :channel_id, channel_id)})

    push(session, Packets.GameToGame.bytes(channel_id, character.map_id, auth_data))
  end
end
