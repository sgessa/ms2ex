defmodule Ms2ex.LoginHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{Accounts, Net, Packets, Sessions}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} <- Sessions.lookup(account_id),
         {:ok, session} <-
           verify_auth_data(auth_data, packet, session) do
      push(session, Packets.MoveResult.bytes())
    else
      _ -> session
    end
  end

  def verify_auth_data(auth_data, packet, session) do
    {token_a, packet} = get_int(packet)
    {token_b, _packet} = get_int(packet)

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
