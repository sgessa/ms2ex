defmodule Ms2ex.Field do
  alias Ms2ex.FieldServer

  def add_character(character) do
    pid = field_pid(character.map_id, character.channel_id)
    call(pid, {:add_character, character})
  end

  def add_object(character, object) do
    pid = field_pid(character.map_id, character.channel_id)
    call(pid, {:add_object, object.object_type, object})
  end

  def broadcast(character_or_field, packet, sender_pid \\ nil)

  def broadcast(%{map_id: field_id, channel_id: channel_id}, packet, sender_pid) do
    pid = field_pid(field_id, channel_id)
    if pid, do: send(pid, {:broadcast, packet, sender_pid})
  end

  def broadcast(pid, packet, sender_pid) do
    send(pid, {:broadcast, packet, sender_pid})
  end

  def enter(%{map_id: field_id} = character, %{channel_id: channel_id} = session) do
    pid = field_pid(field_id, channel_id)

    if pid do
      send(pid, {:add_character, character})
      {:ok, pid}
    else
      GenServer.start(FieldServer, {character, session}, name: field_name(field_id, channel_id))
    end
  end

  def leave(character) do
    pid = field_pid(character.map_id, character.channel_id)
    call(pid, {:remove_character, character.id})
  end

  def push(session_pid, packet), do: send(session_pid, {:push, packet})

  defp field_pid(field_id, channel_id) do
    Process.whereis(field_name(field_id, channel_id))
  end

  defp field_name(field_id, channel_id) do
    :"field:#{field_id}:channel:#{channel_id}"
  end

  defp call(nil, _args), do: :error
  defp call(pid, args), do: GenServer.call(pid, args)
end
