defmodule Ms2ex.GameHandlers.RequestTimeSync do
  import Ms2ex.Packets.PacketReader

  alias Ms2ex.Packets

  def handle(packet, session) do
    {key, _packet} = get_int(packet)
    now = DateTime.utc_now()

    session
    |> Ms2ex.Net.SenderSession.push(
      Packets.ResponseTimeSync.response(Ms2ex.sync_ticks(), DateTime.to_unix(now), 0, 0, key)
    )
  end
end
