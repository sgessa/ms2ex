defmodule Ms2ex.GameHandlers.RequestWorldMap do
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {mode, _packet} = get_byte(packet)
    handle_mode(mode, session)
  end

  # Open
  defp handle_mode(0x0, session) do
    push(session, Packets.WorldMap.open())
  end

  defp handle_mode(_mode, session), do: session
end
