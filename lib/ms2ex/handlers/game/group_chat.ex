defmodule Ms2ex.GameHandlers.GroupChat do
  alias Ms2ex.{GroupChat, Packets, World}

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
    {:ok, character} = World.get_character(session.character_id)
    maybe_create_chat(session, character)
  end

  # Invite
  def handle_mode(0x2, packet, session) do
    {rcpt_name, packet} = get_ustring(packet)
    {chat_id, _packet} = get_int(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         {:ok, rcpt} <- get_rcpt(character, rcpt_name),
         :ok <- validate_rcpt(character, rcpt),
         {:ok, chat} <- get_chat(session, chat_id),
         :ok <- validate_chat(chat) do
      add_character_chat(rcpt, chat)

      {:ok, chat} = World.update_group_chat(chat, rcpt)

      send(rcpt.session_pid, {:push, Packets.GroupChat.update(chat)})
      send(rcpt.session_pid, {:push, Packets.GroupChat.join(character, rcpt, chat)})

      session
      |> push(Packets.GroupChat.invite(character, rcpt, chat))
    else
      _ -> session
    end
  end

  # Leave
  def handle_mode(0x4, packet, session) do
    {chat_id, _packet} = get_int(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         {:ok, chat} <- get_chat(session, chat_id),
         :ok <- World.leave_group_chat(chat, character) do
      push(session, Packets.GroupChat.leave(chat))
    else
      _ -> session
    end
  end

  # Chat
  def handle_mode(0xA, packet, session) do
    {msg, packet} = get_ustring(packet)
    {chat_id, _packet} = get_int(packet)

    with {:ok, character} <- World.get_character(session.character_id),
         {:ok, chat} <- get_chat(session, chat_id) do
      for member <- chat.members do
        send(member.session_pid, {:push, Packets.GroupChat.chat(chat, character, msg)})
      end

      session
    else
      :error -> session
      {:error, session} -> session
    end
  end

  defp maybe_create_chat(session, %{group_chats: chats})
       when length(chats) >= @max_chats_per_user do
    session
  end

  defp maybe_create_chat(session, character) do
    chat = %GroupChat{members: [character]}
    {:ok, chat} = World.add_group_chat(chat)

    add_character_chat(character, chat)

    session
    |> push(Packets.GroupChat.update(chat))
    |> push(Packets.GroupChat.create(chat))
  end

  defp get_chat(session, chat_id) do
    case World.get_group_chat(chat_id) do
      {:ok, chat} -> {:ok, chat}
      :error -> {:error, session}
    end
  end

  defp validate_chat(%{members: members}) when length(members) >= @max_chat_members, do: :error
  defp validate_chat(_chat), do: :ok

  defp get_rcpt(character, rcpt_name) do
    case World.get_character_by_name(rcpt_name) do
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

  defp add_character_chat(character, chat) do
    chats = [chat.id | character.group_chats]
    World.update_character(%{character | group_chats: chats})
  end
end
