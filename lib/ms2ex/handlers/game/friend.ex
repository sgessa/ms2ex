defmodule Ms2ex.GameHandlers.Friend do
  alias Ms2ex.{Friends, Packets, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]
  import Ms2ex.GameHandlers.Helper.Friend

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Send Request
  defp handle_mode(0x2, packet, session) do
    {rcpt_name, packet} = get_ustring(packet)
    {msg, _packet} = get_ustring(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         {:ok, rcpt} <- find_rcpt(session.world, rcpt_name),
         :ok <- validate_rcpt(character, rcpt),
         :ok <- check_friend_list_size(character, rcpt, :cannot_add_friends),
         :ok <- check_friend_list_size(rcpt, rcpt, :rcpt_cannot_add_friends),
         :ok <- check_block_list(character, rcpt),
         :ok <- check_is_already_friend(character, rcpt),
         {:ok, {src, dst}} <- Friends.add(character, rcpt, msg) do
      if Map.get(rcpt, :session_pid) do
        # rcpt = Characters.preload(rcpt, :friends, force: true)
        rcpt = Map.put(rcpt, :friends, [dst | rcpt.friends])
        World.update_character(session.world, rcpt)
        send(rcpt.session_pid, {:push, Packets.Friend.add_to_list(session.world, dst)})
      end

      session
      |> push(Packets.Friend.notice(:request_sent, rcpt_name))
      |> push(Packets.Friend.add_to_list(session.world, src))
    else
      {:error, notice_packet} ->
        push(session, notice_packet)
    end
  end

  # Accept
  defp handle_mode(0x3, _packet, session) do
    session
  end

  # Decline
  defp handle_mode(0x4, _packet, session) do
    session
  end

  # Block
  defp handle_mode(0x5, _packet, session) do
    session
  end

  # Unblock
  defp handle_mode(0x6, _packet, session) do
    session
  end

  # Remove Friend
  defp handle_mode(0x7, _packet, session) do
    session
  end

  # Edit Block Reason
  defp handle_mode(0xA, _packet, session) do
    session
  end

  # Cancel Request
  defp handle_mode(0x11, _packet, session) do
    session
  end

  defp handle_mode(_mode, _packet, session), do: session
end
