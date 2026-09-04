defmodule Ms2ex.GameHandlers.MyInfo do
  @moduledoc """
  The motto shown on the player's profile and above their head.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  import Ms2ex.Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @set_motto 0x0
  @max_length 20

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  defp handle_mode(@set_motto, packet, session) do
    {motto, _packet} = get_ustring(packet)

    if String.length(motto) > @max_length do
      push(
        session,
        Packets.MyInfo.error("The motto can only be up to #{@max_length} letters long.")
      )
    else
      set_motto(session, motto)
    end
  end

  defp handle_mode(_mode, _packet, session), do: session

  defp set_motto(session, motto) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, %Schema.Character{} = character} <-
           Context.Characters.update(character, %{motto: motto}) do
      Managers.Character.call(character, {:update, character})

      Context.Field.broadcast(character, Packets.MyInfo.update_motto(character))
      Context.Field.broadcast(character, Packets.ProxyGameObj.update_motto(character))
    end

    session
  end
end
