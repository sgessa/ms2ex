defmodule Ms2ex.GameHandlers.ResponseClientSyncTick do
  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {server_tick, packet} = get_int(packet)

    if session.server_tick == server_tick do
      {client_tick, _packet} = get_int(packet)
      send(self(), {:update, %{session | client_tick: client_tick}})
    end
  end
end
