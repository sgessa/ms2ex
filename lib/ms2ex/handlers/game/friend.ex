defmodule Ms2ex.GameHandlers.Friend do
  alias Ms2ex.{CharacterManager, Friends, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Ms2ex.GameHandlers.Helper.Friend

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Send Request
  defp handle_mode(0x2, packet, session) do
    {rcpt_name, packet} = get_ustring(packet)
    {msg, _packet} = get_ustring(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, rcpt} <- find_rcpt(rcpt_name),
         :ok <- validate_rcpt(character, rcpt),
         :ok <- check_friend_list_size(character, rcpt, :cannot_add_friends),
         :ok <- check_friend_list_size(rcpt, rcpt, :rcpt_cannot_add_friends),
         :ok <- check_block_list(character, rcpt),
         :ok <- check_is_already_friend(character, rcpt),
         {:ok, {src, dst}} <- Friends.send_request(character, rcpt, msg) do
      if Map.get(rcpt, :session_pid) do
        rcpt = Map.put(rcpt, :friends, [dst | rcpt.friends])
        CharacterManager.update(rcpt)
        push(rcpt, Packets.Friend.add_to_list(dst))
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

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %{status: :accepted, rcpt: sender} = dst_req <-
           Friends.get_by_character_and_shared_id(session.character_id, shared_id, true),
         %{status: :pending} = src_req <-
           Friends.get_by_character_and_shared_id(sender.id, shared_id) do
      {:ok, dst_req} = Friends.update(dst_req, %{is_request: false})
      {:ok, src_req} = Friends.update(src_req, %{status: :accepted})

      with {:ok, sender_session} <- CharacterManager.lookup_by_name(sender.name) do
        src_req = Map.put(src_req, :rcpt, character)

        Friends.subscribe(sender_session, character.id)

        push(sender_session, Packets.Friend.update(src_req))
        push(sender_session, Packets.Friend.accept_notification(shared_id))
      end

      Friends.subscribe(session, sender.id)

      session
      |> push(Packets.Friend.accept(dst_req))
      |> push(Packets.Friend.update(dst_req))
    end
  end

  # Decline
  defp handle_mode(0x4, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %{status: :accepted, rcpt: sender} <-
           Friends.get_by_character_and_shared_id(session.character_id, shared_id, true),
         %{status: :pending} <-
           Friends.get_by_character_and_shared_id(sender.id, shared_id) do
      Friends.delete_all(shared_id)

      with {:ok, sender_session} <- CharacterManager.lookup_by_name(sender.name) do
        remove_friend_from_session(sender_session, shared_id)
        req = %{shared_id: shared_id, rcpt: character}
        push(sender_session, Packets.Friend.remove(req))
      end

      remove_friend_from_session(character, shared_id)
      push(session, Packets.Friend.decline(shared_id))
    end
  end

  # Block
  defp handle_mode(0x5, packet, session) do
    {shared_id, packet} = get_long(packet)
    {rcpt_name, packet} = get_ustring(packet)
    {reason, _packet} = get_ustring(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         :ok <- check_block_list_size(character, rcpt_name, :cannot_block),
         {:ok, rcpt} <- find_rcpt(rcpt_name) do
      if shared_id == 0 do
        block(session, character, rcpt, reason)
      else
        block_friend(session, shared_id, character, rcpt, reason)
      end
    end
  end

  # Unblock
  defp handle_mode(0x6, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         src <-
           Friends.get_by_character_and_shared_id(character.id, shared_id, true) do
      remove_friend_from_session(character, shared_id)
      Friends.delete(src)

      session
      |> push(Packets.Friend.unblock(shared_id))
      |> push(Packets.Friend.remove(src))
    end
  end

  # Remove Friend
  defp handle_mode(0x7, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %{rcpt: rcpt} = friend <-
           Friends.get_by_character_and_shared_id(character.id, shared_id, true) do
      Friends.delete_all(shared_id)

      with {:ok, rcpt_session} <- CharacterManager.lookup_by_name(rcpt.name) do
        remove_friend_from_session(rcpt_session, shared_id)
        req = %{shared_id: shared_id, rcpt: character}

        Friends.unsubscribe(rcpt_session, character.id)
        push(rcpt_session, Packets.Friend.remove(req))
      end

      remove_friend_from_session(character, shared_id)

      Friends.unsubscribe(session, rcpt.id)
      push(session, Packets.Friend.remove(friend))
    end
  end

  # Edit Block Reason
  defp handle_mode(0xA, packet, session) do
    {shared_id, packet} = get_long(packet)
    {rcpt_name, packet} = get_ustring(packet)
    {new_reason, _packet} = get_ustring(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         friend <-
           Friends.get_by_character_and_shared_id(character.id, shared_id, true),
         true <- rcpt_name == friend.rcpt.name,
         {:ok, friend} <- Friends.update(friend, %{block_reason: new_reason}) do
      push(session, Packets.Friend.edit_block_reason(friend))
    end
  end

  # Cancel Request
  defp handle_mode(0x11, packet, session) do
    {shared_id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %{status: :pending, rcpt: rcpt} <-
           Friends.get_by_character_and_shared_id(session.character_id, shared_id, true),
         %{is_request: true} = dst <-
           Friends.get_by_character_and_shared_id(rcpt.id, shared_id) do
      Friends.delete_all(shared_id)

      with {:ok, rcpt_session} <- CharacterManager.lookup_by_name(rcpt.name) do
        remove_friend_from_session(rcpt_session, shared_id)
        dst = Map.put(dst, :rcpt, character)
        push(rcpt_session, Packets.Friend.remove(dst))
      end

      remove_friend_from_session(character, shared_id)
      push(session, Packets.Friend.cancel(shared_id))
    end
  end

  defp handle_mode(_mode, _packet, session), do: session

  defp block(session, character, rcpt, reason) do
    with {:ok, block} <- Friends.block(character, rcpt, reason) do
      rcpt = Map.put(rcpt, :friends, [block | rcpt.friends])
      CharacterManager.update(rcpt)

      session
      |> push(Packets.Friend.add_to_list(block))
      |> push(Packets.Friend.block(block))
    end
  end

  defp block_friend(session, shared_id, character, rcpt, reason) do
    with src <-
           Friends.get_by_character_and_shared_id(character.id, shared_id),
         dst <- Friends.get_by_character_and_shared_id(rcpt.id, shared_id),
         {:ok, {src, _dst}} <- Friends.block_friend(src, dst, reason) do
      src = Map.put(src, :rcpt, rcpt)

      if Map.get(rcpt, :session_pid) do
        remove_friend_from_session(rcpt, shared_id)
        dst = Map.put(dst, :rcpt, character)

        Friends.unsubscribe(rcpt, character.id)
        send(rcpt.session_pid, {:push, Packets.Friend.remove(dst)})
      end

      remove_friend_from_session(character, shared_id)

      Friends.unsubscribe(session, rcpt.id)

      session
      |> push(Packets.Friend.update(src))
      |> push(Packets.Friend.block(src))
    end
  end
end
