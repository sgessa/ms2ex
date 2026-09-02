defmodule Ms2ex.GameHandlers.RequestQuit do
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Managers.Session

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, _packet} = get_byte(packet)
    handle_quit(mode, session)
  end

  defp handle_quit(0x0, session) do
    {:ok, session_data} = Session.lookup(session.account.id)
    push(session, Packets.GameToLogin.bytes(session_data))
  end

  defp handle_quit(_mode, session), do: session
end
