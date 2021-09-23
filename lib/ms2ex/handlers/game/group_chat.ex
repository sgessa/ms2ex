defmodule Ms2ex.GameHandlers.GroupChat do
  alias Ms2ex.{CharacterManager, GroupChat, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  @max_chats_per_user GroupChat.max_chats_per_user()
  @max_chat_members GroupChat.max_members()
  @error %{offline_player: 0x3, max_groups: 0xA, inappropriate_name: 0xD}

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Create
  def handle_mode(0x1, _packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)
    maybe_create_chat(session, character)
  end

  # Invite
  def handle_mode(0x2, packet, session) do
    {rcpt_name, packet} = get_ustring(packet)
    {chat_id, _packet} = get_int(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, rcpt} <- get_rcpt(character, rcpt_name),
         :ok <- validate_rcpt(character, rcpt),
         {:ok, chat} <- get_chat(character, chat_id),
         :ok <- validate_chat(chat) do
      ids = [chat.id | rcpt.group_chat_ids]
      CharacterManager.update(%{rcpt | group_chat_ids: ids})

      {:ok, chat} = GroupChat.add_member(chat, rcpt)
      GroupChat.broadcast(chat.id, Packets.GroupChat.update_members(chat, rcpt))

      send(rcpt.session_pid, {:join_group_chat, character, rcpt, chat})
      push(session, Packets.GroupChat.invite(character, rcpt, chat))
    else
      _ -> session
    end
  end

  # Leave
  def handle_mode(0x4, packet, session) do
    {chat_id, _packet} = get_int(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, chat} <- get_chat(character, chat_id),
         {:ok, chat} <- GroupChat.remove_member(chat, character) do
      GroupChat.unsubscribe(chat)
      GroupChat.broadcast(chat.id, Packets.GroupChat.leave_notice(chat, character))

      chat_ids = Enum.reject(character.group_chat_ids, &(&1 == chat.id))
      CharacterManager.update(%{character | group_chat_ids: chat_ids})

      push(session, Packets.GroupChat.leave(chat))
    else
      _ -> session
    end
  end

  # Chat
  def handle_mode(0xA, packet, session) do
    {msg, packet} = get_ustring(packet)
    {chat_id, _packet} = get_int(packet)

    if msg == "boom", do: raise(msg)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, chat} <- get_chat(character, chat_id) do
      GroupChat.broadcast(chat.id, Packets.GroupChat.chat(chat, character, msg))
      session
    else
      _ -> session
    end
  end

  defp maybe_create_chat(session, %{group_chat_ids: ids})
       when length(ids) >= @max_chats_per_user do
    session
  end

  defp maybe_create_chat(session, character) do
    chat = %GroupChat{id: Ms2ex.generate_id(), member_ids: [character.id]}
    {:ok, _} = GroupChat.start(chat)
    GroupChat.subscribe(chat)

    ids = [chat.id | character.group_chat_ids]
    CharacterManager.update(%{character | group_chat_ids: ids})

    session
    |> push(Packets.GroupChat.update(%{chat | members: [character]}))
    |> push(Packets.GroupChat.create(chat))
  end

  defp get_chat(member, chat_id) do
    with {:ok, chat} <- GroupChat.lookup(chat_id),
         true <- Enum.member?(chat.member_ids, member.id) do
      {:ok, chat}
    else
      _ -> :error
    end
  end

  defp validate_chat(%{member_ids: ids}) when length(ids) >= @max_chat_members, do: :error

  defp validate_chat(_chat), do: :ok

  defp get_rcpt(character, rcpt_name) do
    case CharacterManager.lookup_by_name(rcpt_name) do
      {:ok, rcpt} ->
        {:ok, rcpt}

      :error ->
        character.session_pid
        |> send({:push, Packets.GroupChat.error(@error.offline_player, character, rcpt_name)})

        :error
    end
  end

  defp validate_rcpt(character, %{group_chats: chats} = rcpt)
       when length(chats) >= @max_chats_per_user do
    character.session_pid
    |> send({:push, Packets.GroupChat.error(@error.max_groups, character, rcpt.name)})

    :error
  end

  defp validate_rcpt(_character, _rcpt), do: :ok
end
