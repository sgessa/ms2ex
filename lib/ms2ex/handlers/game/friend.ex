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

    with {:ok, character} <- World.get_character(session.character_id),
         {:ok, rcpt} <- find_rcpt(rcpt_name),
         :ok <- validate_rcpt(character, rcpt),
         :ok <- check_friend_list_size(character, rcpt, :cannot_add_friends),
         :ok <- check_friend_list_size(rcpt, rcpt, :rcpt_cannot_add_friends),
         :ok <- check_block_list(character, rcpt),
         :ok <- check_is_already_friend(character, rcpt),
         {:ok, {src, dst}} <- Friends.add(character, rcpt, msg) do
      if Map.get(rcpt, :session_pid) do
        rcpt = Map.put(rcpt, :friends, [dst | rcpt.friends])
        World.update_character(rcpt)
        send(rcpt.session_pid, {:push, Packets.Friend.add_to_list(dst)})
      end

      session
      |> push(Packets.Friend.notice(:request_sent, rcpt_name))
      |> push(Packets.Friend.add_to_list(src))
    else
      {:error, notice_packet} ->
        push(session, notice_packet)
    end
  end

  # Accept
  defp handle_mode(0x3, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         %{status: :accepted, rcpt: sender} = dst_req <-
           Friends.get_by_character_and_shared_id(session.character_id, shared_id, true),
         %{status: :pending} = src_req <-
           Friends.get_by_character_and_shared_id(sender.id, shared_id) do
      {:ok, dst_req} = Friends.update(dst_req, %{is_request: false})
      {:ok, src_req} = Friends.update(src_req, %{status: :accepted})

      with {:ok, sender_session} <- World.get_character_by_name(sender.name) do
        src_req = Map.put(src_req, :rcpt, character)
        send(sender_session.session_pid, {:push, Packets.Friend.update(src_req)})
        send(sender_session.session_pid, {:push, Packets.Friend.accept_notification(shared_id)})
      end

      session
      |> push(Packets.Friend.accept(shared_id, sender))
      |> push(Packets.Friend.update(dst_req))
      |> push(Packets.Friend.presence_notification(shared_id, sender))
    else
      _ -> session
    end
  end

  # Decline
  defp handle_mode(0x4, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         %{status: :accepted, rcpt: sender} <-
           Friends.get_by_character_and_shared_id(session.character_id, shared_id, true),
         %{status: :pending} <-
           Friends.get_by_character_and_shared_id(sender.id, shared_id) do
      Friends.delete(shared_id)

      with {:ok, sender_session} <- World.get_character_by_name(sender.name) do
        remove_friend_from_session(sender_session, shared_id)
        send(sender_session.session_pid, {:push, Packets.Friend.remove(shared_id, character)})
      end

      remove_friend_from_session(character, shared_id)
      push(session, Packets.Friend.decline(shared_id))
    else
      _ -> session
    end
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
  defp handle_mode(0x7, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         %{rcpt: sender} <-
           Friends.get_by_character_and_shared_id(session.character_id, shared_id, true) do
      Friends.delete(shared_id)

      with {:ok, sender_session} <- World.get_character_by_name(sender.name) do
        remove_friend_from_session(sender_session, shared_id)
        send(sender_session.session_pid, {:push, Packets.Friend.remove(shared_id, character)})
      end

      remove_friend_from_session(character, shared_id)
      push(session, Packets.Friend.remove(shared_id, sender))
    else
      _ -> session
    end
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
