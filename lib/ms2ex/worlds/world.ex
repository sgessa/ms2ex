defmodule Ms2ex.World do
  def broadcast(world, packet, sender_pid \\ nil) do
    Swarm.send(world, {:broadcast, packet, sender_pid})
  end

  def get_character(world, character_id) do
    call(world, {:get_character, character_id})
  end

  def get_characters(world, ids) do
    call(world, {:get_characters, ids})
  end

  def get_character_by_name(world, character_name) do
    call(world, {:get_character_by_name, character_name})
  end

  def update_character(world, character) do
    call(world, {:update_character, character})
  end

  def monitor_character(world, character) do
    call(world, {:monitor, character})
  end

  def add_group_chat(world, group_chat) do
    call(world, {:add_group_chat, group_chat})
  end

  def get_group_chat(world, group_chat_id) do
    call(world, {:get_group_chat, group_chat_id})
  end

  def leave_group_chat(world, group_chat, character) do
    call(world, {:leave_group_chat, group_chat, character})
  end

  def update_group_chat(world, group_chat, new_member) do
    call(world, {:update_group_chat, group_chat, new_member})
  end

  defp call(world, msg) do
    GenServer.call({:via, :swarm, world}, msg)
  end
end
