defmodule Ms2ex.GameHandlers.UserChat do
  alias Ms2ex.{Chat, Commands, Field, Net, Packets, PartyServer, World}

  import Packets.PacketReader
  import Net.Session, only: [push: 2]

  def handle(packet, session) do
    {type_id, packet} = get_int(packet)
    type = Chat.type_from_int(type_id)

    {msg, packet} = get_ustring(packet)
    {rcpt, packet} = get_ustring(packet)
    {_, _packet} = get_long(packet)

    {:ok, character} = World.get_character(session.character_id)

    case msg do
      "!" <> cmd ->
        cmd
        |> String.trim()
        |> String.split(" ")
        |> Commands.handle(character, session)

      _ ->
        handle_message({type, msg, rcpt}, character, session)
    end
  end

  defp handle_message({:all, msg, _rcpt_name}, character, session) do
    packet = Packets.UserChat.bytes(:all, character, msg)
    Field.broadcast(character, packet)
    session
  end

  defp handle_message({:whisper_to, msg, rcpt_name}, character, session) do
    case World.get_character_by_name(rcpt_name) do
      {:ok, rcpt} ->
        packet = Packets.UserChat.bytes(:whisper_from, character, msg)
        send(rcpt.session_pid, {:push, packet})

        push(session, Packets.UserChat.bytes(:whisper_to, rcpt, msg))

      _ ->
        reason = "Player is not online."
        push(session, Packets.UserChat.bytes(:notice_alert, character, reason))
    end
  end

  defp handle_message({:world, msg, _rcpt_name}, character, session) do
    # TODO check if user has enough merets or a voucher
    packet = Packets.UserChat.bytes(:world, character, msg)
    World.broadcast(packet)
    session
  end

  defp handle_message({:party, msg, _rcpt_name}, character, session) do
    packet = Packets.UserChat.bytes(:party, character, msg)

    if character.party_id do
      PartyServer.broadcast(character.party_id, packet)
    end

    session
  end

  defp handle_message(_msg, _character, session), do: session
end
