defmodule Ms2ex.GameHandlers.LoadUgcMap do
  alias Ms2ex.Packets

  import Ms2ex.Net.Session, only: [push: 2]

  def handle(_packet, session) do
    push(session, Packets.LoadUgcMap.bytes())
  end
end
