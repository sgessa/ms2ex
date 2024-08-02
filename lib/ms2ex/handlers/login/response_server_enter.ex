defmodule Ms2ex.LoginHandlers.ResponseServerEnter do
  require Logger

  alias Ms2ex.{Context, Net, Packets}

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {0x2, _packet} = get_byte(packet)

    characters = Context.Characters.list(session.account)

    session
    |> push(Packets.BannerList.bytes())
    |> push(Packets.ServerList.bytes())
    |> push(Packets.CharacterMaxCount.set_max(4, 6))
    |> push(Packets.CharacterList.start_list())
    |> push(Packets.CharacterList.add_entries(characters))
    |> push(Packets.CharacterList.end_list())
  end
end
