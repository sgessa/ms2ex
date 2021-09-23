defmodule Ms2ex.WorldServer do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{characters: %{}, group_chats: %{}, group_chat_counter: 1}}
  end

  # TODO rework group chat
  # def handle_call({:get_group_chat, group_chat_id}, _from, state) do
  #   if group_chat = Map.get(state.group_chats, group_chat_id) do
  #     {:reply, {:ok, group_chat}, state}
  #   else
  #     {:reply, :error, state}
  #   end
  # end
end
