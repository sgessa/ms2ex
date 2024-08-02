defmodule Ms2ex.LoginHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{Context, Net, Packets, SessionManager}

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} <- SessionManager.lookup(account_id),
         {:ok, _} <- verify_auth_data(auth_data, packet, session) do
      SessionManager.register(account_id, auth_data)
      push(session, Packets.MoveResult.bytes())
    else
      _error ->
        Logger.error("Unauthorized Connection")
    end
  end

  def verify_auth_data(auth_data, packet, session) do
    {token_a, packet} = get_int(packet)
    {token_b, _packet} = get_int(packet)

    with true <- token_a == auth_data.token_a,
         true <- token_b == auth_data.token_b do
      account = Context.Accounts.get(auth_data[:account_id])
      Logger.info("Authorized connection for Account #{account.username}")

      session = %{session | account: account}
      send(self(), {:update, session})

      {:ok, session}
    end
  end
end
