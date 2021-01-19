defmodule Ms2ex.LoginHandlers.ResponseVersion do
  alias Ms2ex.Packets

  import Ms2ex.Net.SessionHandler, only: [push: 2]

  def handle(_packet, session) do
    push(session, Packets.RequestLogin.bytes())
  end
end
