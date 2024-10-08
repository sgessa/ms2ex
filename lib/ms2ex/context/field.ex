defmodule Ms2ex.Context.Field do
  alias Ms2ex.{
    Context,
    Net,
    Packets,
    Schema,
    Storage,
    Managers
  }

  alias Ms2ex.Types.FieldNpc
  alias Phoenix.PubSub

  def add_mob_drop(%FieldNpc{} = field_npc, item) do
    cast(field_npc.field, {:add_mob_drop, field_npc, item})
  end

  def drop_item(%Schema.Character{} = character, item) do
    cast(character.field_pid, {:drop_item, character, item})
  end

  def pickup_item(%Schema.Character{} = character, object_id) do
    call(character.field_pid, {:pickup_item, character, object_id})
  end

  def add_region_skill(%Schema.Character{} = character, region_skill) do
    call(character.field_pid, {:add_region_skill, region_skill})
  end

  def add_mob(%Schema.Character{} = character, %{type: :npc} = npc) do
    send(character.field_pid, {:add_mob, npc, character.position})
  end

  def remove_npc(%FieldNpc{} = field_npc) do
    field_pid = Process.whereis(field_npc.field)
    send(field_pid, {:remove_npc, field_npc})
  end

  def add_object(%Schema.Character{} = character, object) do
    call(character.field_pid, {:add_object, object.object_type, object})
  end

  def enter_battle_stance(%Schema.Character{} = character) do
    cast(character.field_pid, {:enter_battle_stance, character})
  end

  def cancel_battle_stance(%Schema.Character{} = character) do
    cast(character.field_pid, {:cancel_battle_stance, character})
  end

  def broadcast(%Schema.Character{} = character, packet) do
    topic = field_name(character.map_id, character.channel_id)
    broadcast(topic, packet)
  end

  def broadcast(topic, packet) do
    PubSub.broadcast(Ms2ex.PubSub, to_string(topic), {:push, packet})
  end

  def broadcast_from(%Schema.Character{} = character, packet, from) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.broadcast_from(Ms2ex.PubSub, from, to_string(topic), {:push, packet})
  end

  def subscribe(%Schema.Character{} = character) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.subscribe(Ms2ex.PubSub, to_string(topic))
  end

  def unsubscribe(%Schema.Character{} = character) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.unsubscribe(Ms2ex.PubSub, to_string(topic))
  end

  def enter(%Schema.Character{} = character) do
    pid = field_pid(character.map_id, character.channel_id)

    if pid && Process.alive?(pid) do
      call(pid, {:add_character, character})
    else
      GenServer.start(
        Managers.Field,
        character,
        name: field_name(character.map_id, character.channel_id)
      )
    end
  end

  def change_field(character, map_id) do
    with %{} = spawn_point <- Storage.Maps.get_spawn(map_id) do
      change_field(character, map_id, spawn_point.position, spawn_point.rotation)
    end
  end

  def change_field(character, map_id, position, rotation) do
    with :ok <- leave(character) do
      character =
        character
        |> Context.Characters.maybe_discover_map(map_id)
        |> Map.put(:change_map, %{id: map_id, position: position, rotation: rotation})

      Managers.Character.update(character)

      Net.SenderSession.push(
        character,
        Packets.RequestFieldEnter.bytes(map_id, position, rotation)
      )
    end
  end

  def leave(character) do
    call(character.field_pid, {:remove_character, character})
  end

  def field_name(map_id, channel_id) do
    :"field:#{map_id}:channel:#{channel_id}"
  end

  defp field_pid(map_id, channel_id) do
    Process.whereis(field_name(map_id, channel_id))
  end

  def call(%Schema.Character{field_pid: field_pid}, args), do: GenServer.call(field_pid, args)
  def call(nil, _args), do: :error
  def call(pid, args), do: GenServer.call(pid, args)

  def cast(%Schema.Character{field_pid: field_pid}, args), do: GenServer.cast(field_pid, args)
  def cast(nil, _args), do: :error
  def cast(pid, args), do: GenServer.cast(pid, args)
end
