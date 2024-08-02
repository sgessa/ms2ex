defmodule Ms2ex.LoginHandlers.ResponseLogin do
  require Logger

  alias Ms2ex.{Context, Net, Packets, SessionManager}

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    {username, packet} = get_ustring(packet)
    {password, _packet} = get_ustring(packet)

    with {:ok, account} <- Context.Accounts.authenticate(username, password),
         :ok <- check_if_already_logged_in(account.id) do
      Logger.info("Account #{username} logged in")

      SessionManager.register(account.id, %{})
      send(self(), {:update, %{account: account}})

      account = %{account | characters: Context.Characters.list(account)}
      handle_login(mode, account, session)
    else
      {:error, :invalid_credentials} -> push(session, Packets.LoginResult.error(:incorrect_id))
      {:error, :already_logged_in} -> push(session, Packets.LoginResult.error(:already_logged_in))
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

  defp check_if_already_logged_in(account_id) do
    case SessionManager.lookup(account_id) do
      :error -> :ok
      {:ok, %{pids: []}} -> :ok
      _ -> {:error, :already_logged_in}
    end
  end
end
