defmodule Ms2ex.Field do
  alias Ms2ex.{
    Character,
    Characters,
    CharacterManager,
    FieldServer,
    Mob,
    Net,
    Packets,
    Storage
  }

  alias Phoenix.PubSub

  def add_mob_drop(%Mob{} = mob, item) do
    cast(mob.field, {:add_mob_drop, mob, item})
  end

  def drop_item(%Character{} = character, item) do
    cast(character.field_pid, {:drop_item, character, item})
  end

  def pickup_item(%Character{} = character, object_id) do
    call(character.field_pid, {:pickup_item, character, object_id})
  end

  def add_region_skill(%Character{} = character, region_skill) do
    call(character.field_pid, {:add_region_skill, character.position, region_skill})
  end

  def add_status(%Character{} = character, status) do
    call(character.field_pid, {:add_status, status})
  end

  def add_mob(%Character{} = character, %{type: :npc} = npc) do
    send(character.field_pid, {:add_mob, npc, character.position})
  end

  def add_object(%Character{} = character, object) do
    call(character.field_pid, {:add_object, object.object_type, object})
  end

  def enter_battle_stance(%Character{} = character) do
    cast(character.field_pid, {:enter_battle_stance, character})
  end

  def cancel_battle_stance(%Character{} = character) do
    cast(character.field_pid, {:cancel_battle_stance, character})
  end

  def broadcast(%Character{} = character, packet) do
    topic = field_name(character.field_id, character.channel_id)
    PubSub.broadcast(Ms2ex.PubSub, to_string(topic), {:push, packet})
  end

  def broadcast(topic, packet) do
    PubSub.broadcast(Ms2ex.PubSub, to_string(topic), {:push, packet})
  end

  def broadcast_from(%Character{} = character, packet, from) do
    topic = field_name(character.field_id, character.channel_id)
    PubSub.broadcast_from(Ms2ex.PubSub, from, to_string(topic), {:push, packet})
  end

  def subscribe(%Character{} = character) do
    topic = field_name(character.field_id, character.channel_id)
    PubSub.subscribe(Ms2ex.PubSub, to_string(topic))
  end

  def unsubscribe(%Character{} = character) do
    topic = field_name(character.field_id, character.channel_id)
    PubSub.unsubscribe(Ms2ex.PubSub, to_string(topic))
  end

  def enter(%Character{} = character) do
    pid = field_pid(character.field_id, character.channel_id)

    if pid && Process.alive?(pid) do
      call(pid, {:add_character, character})
    else
      GenServer.start(
        FieldServer,
        character,
        name: field_name(character.field_id, character.channel_id)
      )
    end
  end

  def change_field(character, field_id) do
    with %{} = spawn_point <- Storage.Maps.get_spawn(field_id) do
      change_field(character, field_id, spawn_point.position, spawn_point.rotation)
    end
  end

  def change_field(character, field_id, position, rotation) do
    with :ok <- leave(character) do
      character =
        character
        |> Characters.maybe_discover_map(field_id)
        |> Map.put(:change_map, %{id: field_id, position: position, rotation: rotation})

      CharacterManager.update(character)

      Net.SenderSession.push(
        character,
        Packets.RequestFieldEnter.bytes(field_id, position, rotation)
      )
    end
  end

  def leave(character) do
    call(character.field_pid, {:remove_character, character})
  end

  def field_name(field_id, channel_id) do
    :"field:#{field_id}:channel:#{channel_id}"
  end

  defp field_pid(field_id, channel_id) do
    Process.whereis(field_name(field_id, channel_id))
  end

  defp call(nil, _args), do: :error
  defp call(pid, args), do: GenServer.call(pid, args)

  defp cast(nil, _args), do: :error
  defp cast(pid, args), do: GenServer.cast(pid, args)
end
