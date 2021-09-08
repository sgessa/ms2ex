defmodule Ms2ex.LoginHandlers.ResponseLogin do
  require Logger

  alias Ms2ex.{Accounts, Characters, Net, Packets, Sessions}

  import Packets.PacketReader
  import Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    {username, packet} = get_ustring(packet)
    {password, _packet} = get_ustring(packet)

    with {:ok, account} <- Accounts.authenticate(username, password),
         :ok <- check_if_already_logged_in(account.id) do
      Logger.info("Account #{username} logged in")

      IO.inspect("TRACK EMPTY SESSION")
      Sessions.register(account.id, %{})

      session = Map.put(session, :account, account)
      account = %{account | characters: Characters.list(account)}
      handle_login(mode, account, session)
    else
      {:error, :invalid_credentials} -> push(session, Packets.LoginResult.incorrect_id())
      {:error, :already_logged_in} -> push(session, Packets.LoginResult.already_logged_in())
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
    case Sessions.lookup(account_id) do
      :error -> :ok
      {:ok, %{pids: []}} -> :ok
      _ -> {:error, :already_logged_in}
    end
  end
end
