defmodule Ms2ex.WorldServer do
  use GenServer

  alias Ms2ex.{GroupChat, Packets}

  import Ms2ex.GameHandlers.Helper.Session, only: [cleanup: 1]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{characters: %{}, group_chats: %{}, group_chat_counter: 1}}
  end

  def handle_call({:get_character, character_id}, _from, state) do
    if character = Map.get(state.characters, character_id) do
      {:reply, {:ok, character}, state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:get_characters, ids}, _from, state) do
    characters = Enum.filter(state.characters, fn {id, _char} -> id in ids end)
    {:reply, characters, state}
  end

  def handle_call({:get_character_by_name, character_name}, _from, state) do
    case Enum.find(state.characters, fn {_id, char} -> char.name == character_name end) do
      {_char_id, character} ->
        {:reply, {:ok, character}, state}

      _ ->
        {:reply, :error, state}
    end
  end

  def handle_call({:update_character, character}, _from, state) do
    {:reply, :ok, update_character(state, character)}
  end

  def handle_call({:monitor, character}, _from, state) do
    Process.monitor(character.session_pid)
    {:reply, :ok, state}
  end

  def handle_call({:add_group_chat, group_chat}, _from, %{group_chat_counter: counter} = state) do
    group_chat = %{group_chat | id: counter}
    group_chats = Map.put(state.group_chats, counter, group_chat)

    {:reply, {:ok, group_chat},
     %{state | group_chats: group_chats, group_chat_counter: counter + 1}}
  end

  def handle_call({:get_group_chat, group_chat_id}, _from, state) do
    if group_chat = Map.get(state.group_chats, group_chat_id) do
      {:reply, {:ok, group_chat}, state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:leave_group_chat, group_chat, character}, _from, state) do
    {:reply, :ok, leave_group_chat(character, group_chat, state)}
  end

  def handle_call({:update_group_chat, group_chat, new_member}, _from, state) do
    for char <- group_chat.members do
      send(char.session_pid, {:push, Packets.GroupChat.update_members(group_chat, new_member)})
    end

    group_chat = GroupChat.add_member(group_chat, new_member)
    group_chats = Map.put(state.group_chats, group_chat.id, group_chat)

    {:reply, {:ok, group_chat}, %{state | group_chats: group_chats}}
  end

  def handle_info({:broadcast, packet, sender_pid}, state) do
    for {_char_id, %{session_pid: pid}} <- state.characters, pid != sender_pid do
      send(pid, {:push, packet})
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    case Enum.find(state.characters, fn {_, %{session_pid: char_pid}} -> pid == char_pid end) do
      {char_id, character} ->
        cleanup(%{character | online?: false})

        state = leave_group_chats(character, state)
        characters = Map.delete(state.characters, char_id)
        {:noreply, %{state | characters: characters}}

      _ ->
        {:noreply, state}
    end
  end

  defp leave_group_chats(%{group_chats: chat_ids} = character, state) do
    chats = state.group_chats |> Map.take(chat_ids) |> Map.values()

    Enum.reduce(chats, state, fn chat, state ->
      leave_group_chat(character, chat, state)
    end)
  end

  defp leave_group_chat(character, group_chat, state) do
    if Enum.find(group_chat.members, &(&1.id == character.id)) do
      members = Enum.reject(group_chat.members, &(&1.id == character.id))
      group_chat = %{group_chat | members: members}

      for char <- group_chat.members do
        send(char.session_pid, {:push, Packets.GroupChat.leave_notice(group_chat, character)})
      end

      state
      |> remove_character_chat(character, group_chat)
      |> maybe_remove_group_chat(group_chat)
    else
      state
    end
  end

  defp remove_character_chat(state, character, chat) do
    chats = Enum.reject(character.group_chats, &(&1 == chat.id))
    update_character(state, %{character | group_chats: chats})
  end

  defp update_character(state, character) do
    characters = Map.put(state.characters, character.id, character)
    %{state | characters: characters}
  end

  defp maybe_remove_group_chat(state, %{members: members} = group_chat)
       when length(members) > 0 do
    group_chats = Map.put(state.group_chats, group_chat.id, group_chat)
    %{state | group_chats: group_chats}
  end

  defp maybe_remove_group_chat(state, group_chat) do
    group_chats = Map.delete(state.group_chats, group_chat.id)
    %{state | group_chats: group_chats}
  end
end
