defmodule Ms2ex.LoginHandlers.ResponseLogin do
  require Logger

  alias Ms2ex.{Net, Packets, Users}

  import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    {username, packet} = get_ustring(packet)
    {password, _packet} = get_ustring(packet)

    with {:ok, account} <- Users.authenticate(username, password) do
      Logger.info("Account #{username} logged in")
      account = Users.load_characters(account)
      session = Map.put(session, :account, account)
      handle_login(mode, packet, session)
    end
  end

  defp handle_login(0x1, _packet, session) do
    session
    |> push(Packets.NpsInfo.bytes())
    |> push(Packets.BannerList.bytes())
    |> push(Packets.ServerList.bytes())
  end

  defp handle_login(0x2, _packet, %{account: account} = session) do
    session
    |> push(Packets.LoginResult.bytes(account.id))
    |> push(Packets.UGC.set_endpoint())
    |> push(Packets.CharacterMaxCount.set_max(4, 6))
    |> push(Packets.CharacterList.start_list())
    |> push(Packets.CharacterList.add_entries(account.characters))
    |> push(Packets.CharacterList.end_list())
  end
end
