defmodule Ms2ex.Context.Field do
  @moduledoc """
  Context module for field-related operations.

  This module provides functions for managing field interactions, including
  character movement between maps, object and mob interactions, item pickups,
  and field broadcasts.
  """

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

  @doc """
  Drops an item from a Field NPC (mob) into the field.

  ## Examples

      iex> add_mob_drop(field_npc, item)
      :ok
  """
  @spec add_mob_drop(FieldNpc.t(), Schema.Item.t()) :: :ok | :error
  def add_mob_drop(%FieldNpc{} = field_npc, item) do
    cast(field_npc.field, {:add_mob_drop, field_npc, item})
  end

  @doc """
  Drops an item from a character's inventory into the field.

  ## Examples

      iex> drop_item(character, item)
      :ok
  """
  @spec drop_item(Schema.Character.t(), Schema.Item.t()) :: :ok | :error
  def drop_item(%Schema.Character{} = character, item) do
    cast(character.field_pid, {:drop_item, character, item})
  end

  @doc """
  Picks up an item from the field.

  ## Examples

      iex> pickup_item(character, object_id)
      {:ok, item}
  """
  @spec pickup_item(Schema.Character.t(), integer()) :: {:ok, Schema.Item.t()} | {:error, atom()}
  def pickup_item(%Schema.Character{} = character, object_id) do
    call(character.field_pid, {:pickup_item, character, object_id})
  end

  @doc """
  Adds a region skill (Skill effect) to the field.

  ## Examples

      iex> add_region_skill(character, region_skill)
      {:ok, region_skill_id}
  """
  @spec add_region_skill(Schema.Character.t(), map()) :: {:ok, integer()} | {:error, atom()}
  def add_region_skill(%Schema.Character{} = character, region_skill) do
    call(character.field_pid, {:add_region_skill, region_skill})
  end

  @doc """
  Adds a mob (Field NPC) to the field at the character's position.

  ## Examples

      iex> add_mob(character, npc)
      :ok
  """
  @spec add_mob(Schema.Character.t(), %{type: :npc}) :: :ok
  def add_mob(%Schema.Character{} = character, %{type: :npc} = npc) do
    send(character.field_pid, {:add_mob, npc, character.position})
  end

  @doc """
  Removes an NPC from the field.

  ## Examples

      iex> remove_npc(field_npc)
      :ok
  """
  @spec remove_npc(FieldNpc.t()) :: :ok
  def remove_npc(%FieldNpc{} = field_npc) do
    field_pid = Process.whereis(field_npc.field)
    send(field_pid, {:remove_npc, field_npc})
  end

  @doc """
  Adds an object to the field.

  ## Examples

      iex> add_object(character, object)
      {:ok, object_id}
  """
  @spec add_object(Schema.Character.t(), map()) :: {:ok, integer()} | {:error, atom()}
  def add_object(%Schema.Character{} = character, object) do
    call(character.field_pid, {:add_object, object.object_type, object})
  end

  @doc """
  Puts a character into battle stance.

  ## Examples

      iex> enter_battle_stance(character)
      :ok
  """
  @spec enter_battle_stance(Schema.Character.t()) :: :ok | :error
  def enter_battle_stance(%Schema.Character{} = character) do
    cast(character.field_pid, {:enter_battle_stance, character})
  end

  @doc """
  Cancels a character's battle stance.

  ## Examples

      iex> cancel_battle_stance(character)
      :ok
  """
  @spec cancel_battle_stance(Schema.Character.t()) :: :ok | :error
  def cancel_battle_stance(%Schema.Character{} = character) do
    cast(character.field_pid, {:cancel_battle_stance, character})
  end

  @doc """
  Broadcasts a packet to all characters in the same field as the given character.

  ## Examples

      iex> broadcast(character, packet)
      :ok

      iex> broadcast(:field_123, packet)
      :ok
  """
  @spec broadcast(Schema.Character.t() | term(), binary()) :: :ok
  def broadcast(%Schema.Character{} = character, packet) do
    topic = field_name(character.map_id, character.channel_id)
    broadcast(topic, packet)
  end

  def broadcast(topic, packet) do
    PubSub.broadcast(Ms2ex.PubSub, to_string(topic), {:push, packet})
  end

  @doc """
  Broadcasts a packet to all characters in the same field as the given character,
  except for the specified process.

  ## Examples

      iex> broadcast_from(character, packet, self())
      :ok
  """
  @spec broadcast_from(Schema.Character.t(), binary(), pid()) :: :ok
  def broadcast_from(%Schema.Character{} = character, packet, from) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.broadcast_from(Ms2ex.PubSub, from, to_string(topic), {:push, packet})
  end

  @doc """
  Subscribes the current process to a character's field events.

  ## Examples

      iex> subscribe(character)
      :ok
  """
  @spec subscribe(Schema.Character.t()) :: :ok | {:error, term()}
  def subscribe(%Schema.Character{} = character) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.subscribe(Ms2ex.PubSub, to_string(topic))
  end

  @doc """
  Unsubscribes the current process from a character's field events.

  ## Examples

      iex> unsubscribe(character)
      :ok
  """
  @spec unsubscribe(Schema.Character.t()) :: :ok
  def unsubscribe(%Schema.Character{} = character) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.unsubscribe(Ms2ex.PubSub, to_string(topic))
  end

  @doc """
  Adds a character to a field, creating the field process if it doesn't exist.

  ## Examples

      iex> enter(character)
      {:ok, pid}

      iex> enter(character) # when field already exists
      :ok
  """
  @spec enter(Schema.Character.t()) :: :ok | {:ok, pid()} | {:error, term()}
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

  @doc """
  Changes a character's field to a new map, using the map's default spawn point.

  ## Examples

      iex> change_field(character, 2000)
      :ok
  """
  @spec change_field(Schema.Character.t(), integer()) :: :ok | {:error, term()}
  def change_field(character, map_id) do
    with %{} = spawn_point <- Storage.Maps.get_spawn(map_id) do
      change_field(character, map_id, spawn_point.position, spawn_point.rotation)
    end
  end

  @doc """
  Changes a character's field to a new map with a specific position and rotation.

  ## Examples

      iex> change_field(character, 2000, %{x: 100, y: 200, z: 0}, %{x: 0, y: 0, z: 0})
      :ok
  """
  @spec change_field(Schema.Character.t(), integer(), map(), map()) :: :ok | {:error, term()}
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

  @doc """
  Removes a character from their current field.

  ## Examples

      iex> leave(character)
      :ok
  """
  @spec leave(Schema.Character.t()) :: :ok | {:error, term()}
  def leave(character) do
    call(character.field_pid, {:remove_character, character})
  end

  @doc """
  Generates a unique field name from a map ID and channel ID.

  ## Examples

      iex> field_name(2000, 1)
      :"field:2000:channel:1"
  """
  @spec field_name(integer(), integer()) :: atom()
  def field_name(map_id, channel_id) do
    :"field:#{map_id}:channel:#{channel_id}"
  end

  defp field_pid(map_id, channel_id) do
    Process.whereis(field_name(map_id, channel_id))
  end

  @doc """
  Makes a synchronous call to a field process.

  ## Examples

      iex> call(character, {:action, arg})
      :ok

      iex> call(nil, args)
      :error
  """
  @spec call(Schema.Character.t() | pid() | nil, term()) :: term() | :error
  def call(%Schema.Character{field_pid: field_pid}, args), do: GenServer.call(field_pid, args)
  def call(nil, _args), do: :error
  def call(pid, args), do: GenServer.call(pid, args)

  @doc """
  Makes an asynchronous cast to a field process.

  ## Examples

      iex> cast(character, {:action, arg})
      :ok

      iex> cast(nil, args)
      :error
  """
  @spec cast(Schema.Character.t() | pid() | nil, term()) :: :ok | :error
  def cast(%Schema.Character{field_pid: field_pid}, args), do: GenServer.cast(field_pid, args)
  def cast(nil, _args), do: :error
  def cast(pid, args), do: GenServer.cast(pid, args)
end
