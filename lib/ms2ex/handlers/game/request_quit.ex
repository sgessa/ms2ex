defmodule Ms2ex.GameHandlers.RequestQuit do
  require Logger

  alias Ms2ex.{Net, Packets, Registries}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, _packet} = get_byte(packet)
    handle_quit(mode, session)
  end

  defp handle_quit(0x0, session) do
    {:ok, session_data} = Registries.Sessions.lookup(session.account.id)
    push(session, Packets.GameToLogin.bytes(session_data))
  end

  defp handle_quit(_mode, session), do: session
end
