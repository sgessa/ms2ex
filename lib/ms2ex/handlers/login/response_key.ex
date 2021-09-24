defmodule Ms2ex.LoginHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{Accounts, Net, Packets, SessionManager}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} <- SessionManager.lookup(account_id),
         {:ok, session} <- verify_auth_data(auth_data, packet, session) do
      SessionManager.register(account_id, auth_data)
      push(session, Packets.MoveResult.bytes())
    else
      _ -> session
    end
  end

  def verify_auth_data(auth_data, packet, session) do
    {token_a, packet} = get_int(packet)
    {token_b, _packet} = get_int(packet)

    IO.inspect(token_a, label: "A")
    IO.inspect(token_b, label: "B")
    IO.inspect(auth_data)

    with true <- token_a == auth_data.token_a,
         true <- token_b == auth_data.token_b do
      account = Accounts.get(auth_data[:account_id])
      Logger.info("Authorized connection for Account #{account.username}")
      {:ok, Map.put(session, :account, account)}
    else
      _ ->
        Logger.error("Unauthorized Connection")
        {:error, session}
    end
  end
end
