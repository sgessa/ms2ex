defmodule Ms2ex.GameHandlers.ResponseVersion do
  alias Ms2ex.Packets

  import Ms2ex.Net.SessionHandler, only: [push: 2]

  def handle(_packet, session) do
    session
    |> push(Packets.UnknownSync.sync())
    |> push(Packets.RequestKey.bytes())
  end
end
