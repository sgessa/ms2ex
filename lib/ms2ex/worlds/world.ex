defmodule Ms2ex.World do
  def broadcast(packet, sender_pid \\ nil) do
    Swarm.send(:world, {:broadcast, packet, sender_pid})
  end

  def get_character(character_id) do
    call({:get_character, character_id})
  end

  def get_characters(ids) do
    call({:get_characters, ids})
  end

  def get_character_by_name(character_name) do
    call({:get_character_by_name, character_name})
  end

  def update_character(character) do
    call({:update_character, character})
  end

  def monitor_character(character) do
    call({:monitor, character})
  end

  def add_group_chat(group_chat) do
    call({:add_group_chat, group_chat})
  end

  def get_group_chat(group_chat_id) do
    call({:get_group_chat, group_chat_id})
  end

  def leave_group_chat(group_chat, character) do
    call({:leave_group_chat, group_chat, character})
  end

  def update_group_chat(group_chat, new_member) do
    call({:update_group_chat, group_chat, new_member})
  end

  def send_presence_notification(friend) do
    Swarm.send(:world, {:presence_notification, friend})
  end

  defp call(msg) do
    GenServer.call({:via, :swarm, :world}, msg)
  end
end
