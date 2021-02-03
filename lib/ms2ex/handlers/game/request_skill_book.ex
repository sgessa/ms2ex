defmodule Ms2ex.GameHandlers.RequestSkillBook do
  require Logger

  alias Ms2ex.{Net, Packets, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, _packet} = get_byte(packet)
    {:ok, character} = World.get_character(session.world, session.character_id)
    handle_mode(mode, character, session)
  end

  defp handle_mode(0x0, character, session) do
    push(session, Packets.ResponseSkillBook.open(character))
  end

  defp handle_mode(0x1, character, session) do
    push(session, Packets.ResponseSkillBook.save(character))
  end

  defp handle_mode(_mode, _character, session), do: session
end
