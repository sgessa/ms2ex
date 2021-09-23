defmodule Ms2ex.GroupChat do
  use GenServer

  alias Ms2ex.CharacterManager
  alias Phoenix.PubSub

  defstruct [:id, members: [], member_ids: []]

  @max_members 20
  def max_members(), do: @max_members

  @max_chats_per_user 3
  def max_chats_per_user(), do: @max_chats_per_user

  def start(%__MODULE__{} = chat) do
    GenServer.start(__MODULE__, chat, name: process_name(chat.id))
  end

  def lookup(chat_id) do
    case Process.whereis(process_name(chat_id)) do
      nil -> :error
      _pid -> call(chat_id, :lookup)
    end
  end

  def load_members(%__MODULE__{} = chat) do
    members =
      Enum.reduce(chat.member_ids, [], fn id, members ->
        case CharacterManager.lookup(id) do
          {:ok, member} -> [member | members]
          _ -> members
        end
      end)

    Map.put(chat, :members, members)
  end

  def add_member(%__MODULE__{id: chat_id}, new_member) do
    call(chat_id, {:add_member, new_member})
  end

  def remove_member(%__MODULE__{id: chat_id}, member) do
    call(chat_id, {:remove_member, member})
  end

  def subscribe(%__MODULE__{id: chat_id}) do
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, topic(chat_id))
  end

  def unsubscribe(%__MODULE__{id: chat_id}) do
    Phoenix.PubSub.unsubscribe(Ms2ex.PubSub, topic(chat_id))
  end

  def init(chat) do
    {:ok, chat}
  end

  def handle_call(:lookup, _from, chat) do
    {:reply, {:ok, chat}, chat}
  end

  def handle_call({:add_member, new_member}, _from, chat) do
    chat = %{chat | member_ids: [new_member.id | chat.member_ids]}
    {:reply, {:ok, chat}, chat}
  end

  def handle_call({:remove_member, member}, _from, chat) do
    if Enum.member?(chat.member_ids, member.id) do
      member_ids = Enum.reject(chat.member_ids, &(&1 == member.id))
      chat = %{chat | member_ids: member_ids}

      remove_character_chat(member, chat)

      if length(chat.member_ids) < 1 do
        send(self(), :stop)
      end

      {:reply, {:ok, chat}, chat}
    else
      {:reply, :error, chat}
    end
  end

  def handle_info(:stop, chat) do
    {:stop, :normal, chat}
  end

  def broadcast(chat_id, packet) do
    PubSub.broadcast(Ms2ex.PubSub, topic(chat_id), {:push, packet})
  end

  defp remove_character_chat(character, chat) do
    ids = Enum.reject(character.group_chat_ids, &(&1 == chat.id))
    CharacterManager.update(%{character | group_chat_ids: ids})
  end

  defp call(chat_id, msg), do: GenServer.call(process_name(chat_id), msg)

  defp process_name(chat_id), do: :"group_chat:#{chat_id}"

  defp topic(chat_id) do
    chat_id |> process_name() |> to_string()
  end
end
