defmodule Ms2ex.LoginHandlers.ResponseServerEnter do
  require Logger

  alias Ms2ex.{Net, Packets, Users}

  import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

  def handle(packet, session) do
    {0x2, _packet} = get_byte(packet)

    account = Users.load_characters(session.account)

    session
    |> Map.put(:account, account)
    |> push(Packets.BannerList.bytes())
    |> push(Packets.ServerList.bytes())
    |> push(Packets.CharacterMaxCount.set_max(4, 6))
    |> push(Packets.CharacterList.start_list())
    |> push(Packets.CharacterList.add_entries(account.characters))
    |> push(Packets.CharacterList.end_list())
  end
end
