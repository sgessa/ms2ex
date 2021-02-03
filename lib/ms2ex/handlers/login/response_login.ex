defmodule Ms2ex.LoginHandlers.ResponseLogin do
  require Logger

  alias Ms2ex.{Characters, Net, Packets, Accounts}

  import Packets.PacketReader
  import Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    {username, packet} = get_ustring(packet)
    {password, _packet} = get_ustring(packet)

    with {:ok, account} <- Accounts.authenticate(username, password) do
      Logger.info("Account #{username} logged in")
      session = Map.put(session, :account, account)
      account = %{account | characters: Characters.list(account)}
      handle_login(mode, account, session)
    else
      _ -> push(session, Packets.LoginResult.error())
    end
  end

  defp handle_login(0x1, _account, session) do
    session
    |> push(Packets.NpsInfo.bytes())
    |> push(Packets.BannerList.bytes())
    |> push(Packets.ServerList.bytes())
  end

  defp handle_login(0x2, account, session) do
    session
    |> push(Packets.LoginResult.success(account.id))
    |> push(Packets.UGC.set_endpoint())
    |> push(Packets.CharacterMaxCount.set_max(4, 6))
    |> push(Packets.CharacterList.start_list())
    |> push(Packets.CharacterList.add_entries(account.characters))
    |> push(Packets.CharacterList.end_list())
  end
end
