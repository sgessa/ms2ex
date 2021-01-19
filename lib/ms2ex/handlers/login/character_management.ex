defmodule Ms2ex.LoginHandlers.CharacterManagement do
  alias Ms2ex.{Net, Packets}

  import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

  def handle(<<0x0, packet::bytes>>, session) do
    handle_login(packet, session)
  end

  def handle(<<0x1, packet::bytes>>, session) do
    handle_create(packet, session)
  end

  def handle(<<0x2, packet::bytes>>, session) do
    handle_delete(packet, session)
  end

  defp handle_login(packet, %{account: account} = session) do
    {char_id, _packet} = get_long(packet)
    character = Enum.find(account.characters, &(&1.id == char_id))

    auth_data = %{token_a: gen_auth_token(), token_b: gen_auth_token()}
    register_session(account, character, auth_data)

    session
    |> Map.put(:character, character)
    |> push(Packets.LoginToGame.login(auth_data))
  end

  defp handle_create(_packet, session), do: session

  defp handle_delete(_packet, session), do: session

  # Register session data in the global registry.
  # This allows us to lookup the session PID from any server.
  defp register_session(account, character, auth_data) do
    :ok =
      Net.SessionRegistry.register(
        account.id,
        Map.merge(auth_data, %{account_id: account.id, character_id: character.id})
      )
  end

  defp gen_auth_token() do
    floor(:rand.uniform() * floor(:math.pow(2, 31)))
  end
end
