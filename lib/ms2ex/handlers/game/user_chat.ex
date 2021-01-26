defmodule Ms2ex.GameHandlers.UserChat do
  alias Ms2ex.{Chat, Field, Net, Packets, Registries}

  import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

  def handle(packet, session) do
    {type_id, packet} = get_int(packet)
    type = Chat.type_from_int(type_id)

    {msg, packet} = get_ustring(packet)
    {rcpt, packet} = get_ustring(packet)
    {_, _packet} = get_long(packet)

    handle_message({type, type_id}, msg, rcpt, session)
  end

  defp handle_message({:all, type_id}, msg, _rcpt_name, session) do
    with {:ok, char} <- Registries.Characters.lookup(session.character_id) do
      packet = Packets.UserChat.bytes({:all, type_id}, char, msg)
      Field.broadcast(char, packet)
    end

    session
  end

  defp handle_message({:whisper_to, type_id}, msg, rcpt_name, session) do
    {:ok, char} = Registries.Characters.lookup(session.character_id)

    case Registries.Characters.lookup_by_name(rcpt_name) do
      {:ok, rcpt} ->
        packet = Packets.UserChat.bytes({:whisper_from, type_id}, char, msg)
        send(rcpt.session_pid, {:push, packet})

        push(session, Packets.UserChat.bytes({:whisper_to, type_id}, rcpt, msg))

      _ ->
        reason = "Player is not online."
        push(session, Packets.UserChat.bytes({:whisper_to, type_id}, char, reason))
    end
  end

  defp handle_message(_type, _msg, _rcpt_name, session), do: session
end
