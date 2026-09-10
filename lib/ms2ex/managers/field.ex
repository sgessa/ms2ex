defmodule Ms2ex.Managers.Field do
  @moduledoc """
  One field process owns the live state of a single map instance (map +
  channel): the players on it, npcs, items, buffs, trigger-script machines
  and every other field-object system.

  The process state is transformed by the `Managers.Field.*` submodules —
  each owns one field-object system and follows the state-in/state-out
  pattern:

  - `Field.Banner` — UGC banner slots (persistence via `Context.BannerSlots`)
  - `Field.Buff` — effect buffs and their ticks
  - `Field.Character` — the join/leave sequences and periodic stat updates
  - `Field.Instrument` — instruments in play
  - `Field.InteractObject` — interact-object lifecycles
  - `Field.Item` — field drops and pickups
  - `Field.Liftable` — quest liftable props
  - `Field.Npc` — npc spawns, damage/death and spawn cycles
  - `Field.Npc.Patrol` — npc movement along patrol paths
  - `Field.PerformanceStage` — the concert stage
  - `Field.Portal` — portal loading
  - `Field.RegionSkill` — region skill zones and splash ticks
  - `Field.Tombstone` — dead players' tombstones
  - `Field.Trigger` — the trigger-script runtime (see also
    `Field.Trigger.Actions` and `Field.Trigger.Conditions`)

  This module is both the GenServer and the manager's API surface: handlers
  and other processes go through the named functions below (or the generic
  `call/2`/`cast/2` for the field process they are already talking to).
  """

  use GenServer

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  alias Phoenix.PubSub

  @updates_intval 1000
  @npc_tick_intval 15
  @banner_tick_intval :timer.seconds(30)

  # one app-wide counter feeds players and mounts, while each field instance
  # owns a local counter for npcs, portals, spawn points and items
  @local_id_counter 50_000_000

  # -- lifecycle -------------------------------------------------------------

  @doc """
  Persists the character's current map after a field change; the in-memory
  map id follows the new map. Instanced maps persist like any other: the
  reference saves the current stage on quit (only maps that push a
  return-map reset it, which plain solo maps never do), so a relog lands
  in a fresh instance of the same stage.
  """
  @spec update_current_map(Schema.Character.t(), map()) :: Schema.Character.t()
  def update_current_map(%Schema.Character{} = character, %{id: map_id} = _new_map) do
    {:ok, character} = Context.Characters.update(character, %{map_id: map_id})
    character
  end

  @doc """
  Binds the character to a field instance: a pending `change_map` instance
  (fresh allocation from `change_field/2,4`) wins, an existing stamp is
  kept while the character stays on the same field, anything else
  allocates.
  """
  @spec assign_instance(Schema.Character.t()) :: Schema.Character.t()
  def assign_instance(%Schema.Character{change_map: %{instance: instance}} = character),
    do: Map.put(character, :field_instance, instance)

  def assign_instance(%Schema.Character{field_instance: instance} = character)
      when is_integer(instance),
      do: character

  def assign_instance(%Schema.Character{} = character),
    do: Map.put(character, :field_instance, instance_id(character.map_id))

  @doc """
  Adds a character to a field, creating the field process if it doesn't
  exist. Returns `{:ok, pid}` for a fresh field, `{:ok, field_pid}` when the
  character joined an existing one.
  """
  @spec enter(Schema.Character.t()) :: :ok | {:ok, pid()} | {:error, term()}
  def enter(%Schema.Character{} = character) do
    # the instance is allocated once per transition and carried on the
    # character (change_field stamps it into change_map): a repeated field
    # enter for the same visit rejoins the same field instead of spawning
    # another one
    instance = character.field_instance || instance_id(character.map_id)
    character = Map.put(character, :field_instance, instance)
    opts = [name: field_name(character)]

    case GenServer.start(__MODULE__, character, opts) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        call(pid, {:add_character, character})

      result ->
        result
    end
  end

  @doc """
  The field instance id a character enters for the map: solo maps
  (tutorials, quest instances) run one private field per entry, so a
  fresh id is allocated per call; every other map — including
  channel-scale ones — shares a single field per channel (id 0).
  """
  @spec instance_id(integer()) :: integer()
  def instance_id(map_id) do
    if Storage.Tables.InstanceFields.solo?(map_id) do
      System.unique_integer([:positive])
    else
      0
    end
  end

  @doc "Removes a character from their current field."
  @spec leave(Schema.Character.t()) :: :ok | {:error, term()}
  def leave(character) do
    call(character.field_pid, {:remove_character, character})
  end

  @doc """
  Changes a character's field to a new map, using the map's default spawn
  point.
  """
  @spec change_field(Schema.Character.t(), integer()) :: :ok | {:error, term()}
  def change_field(character, map_id) do
    with %{} = spawn_point <- Storage.Maps.get_field_spawn(map_id) do
      change_field(character, map_id, spawn_point.position, spawn_point.rotation)
    end
  end

  @doc "Changes a character's field to a new map at a specific position."
  @spec change_field(Schema.Character.t(), integer(), map(), map()) :: :ok | {:error, term()}
  def change_field(character, map_id, position, rotation) do
    instance = instance_id(map_id)
    change_map = %{id: map_id, position: position, rotation: rotation, instance: instance}

    with :ok <- leave_for_change(character) do
      character =
        character
        |> Context.Characters.maybe_discover_map(map_id)
        |> Map.put(:change_map, change_map)

      Managers.Character.call(character, {:update, character})

      Net.SenderSession.push(
        character,
        Packets.RequestFieldEnter.bytes(map_id, position, rotation)
      )
    end
  end

  defp leave_for_change(%Schema.Character{field_pid: nil}), do: :ok

  defp leave_for_change(%Schema.Character{} = character) do
    case leave(character) do
      :ok -> :ok
      :error -> if is_pid(character.field_pid), do: :ok, else: :error
    end
  end

  # -- distribution ----------------------------------------------------------

  @doc "Broadcasts a packet to every character on a field."
  @spec broadcast(Schema.Character.t() | term(), binary()) :: :ok
  def broadcast(%Schema.Character{} = character, packet) do
    topic = field_name(character)
    broadcast(topic, packet)
  end

  def broadcast(topic, packet) do
    PubSub.broadcast(Ms2ex.PubSub, to_string(topic), {:push, packet})
  end

  @doc """
  Sends the full stat set to the character and the compact player stat
  update to every other character in the same field.
  """
  @spec broadcast_stats(Schema.Character.t()) :: :ok
  def broadcast_stats(%Schema.Character{} = character) do
    broadcast(character, Packets.Stats.set_character_stats(character))

    broadcast_from(
      character,
      Packets.Stats.update_player_stats(character),
      character.sender_session_pid
    )
  end

  @doc """
  Broadcasts a packet to every character on the character's field except
  the given process.
  """
  @spec broadcast_from(Schema.Character.t(), binary(), pid()) :: :ok
  def broadcast_from(%Schema.Character{} = character, packet, from) do
    topic = field_name(character)
    PubSub.broadcast_from(Ms2ex.PubSub, from, to_string(topic), {:push, packet})
  end

  @doc "Subscribes the current process to a character's field events."
  @spec subscribe(Schema.Character.t()) :: :ok | {:error, term()}
  def subscribe(%Schema.Character{} = character) do
    topic = field_name(character)
    PubSub.subscribe(Ms2ex.PubSub, to_string(topic))
  end

  @doc "Unsubscribes the current process from a character's field events."
  @spec unsubscribe(Schema.Character.t()) :: :ok
  def unsubscribe(%Schema.Character{} = character) do
    topic = field_name(character)
    PubSub.unsubscribe(Ms2ex.PubSub, to_string(topic))
  end

  @doc """
  Field process name / PubSub topic for the field a character is on. A
  missing instance id is the map's shared field (instance 0).
  """
  @spec field_name(Schema.Character.t()) :: atom()
  def field_name(%Schema.Character{} = character) do
    field_name(character.map_id, character.channel_id, character.field_instance)
  end

  @doc """
  Generates a unique field process name from a map ID, channel ID and
  instance ID. Instance 0 is the shared field of the map on the channel;
  instanced maps (see `Storage.Tables.InstanceFields`) carry their own id.
  """
  @spec field_name(integer(), integer(), integer() | nil) :: atom()
  def field_name(map_id, channel_id, instance_id) do
    :"field:#{map_id}:channel:#{channel_id}:instance:#{instance_id || 0}"
  end

  # -- process plumbing ------------------------------------------------------

  @doc "Allocates the next field-local object id (npcs, items, effects, ...)."
  def next_local_id(state) do
    id = state.local_id_counter + 1
    {id, %{state | local_id_counter: id}}
  end

  @doc """
  Makes a synchronous call to a character's field process; `:error` when
  the character has no field or the call fails.
  """
  @spec call(Schema.Character.t() | pid() | nil, term()) :: term() | :error
  def call(%Schema.Character{field_pid: field_pid}, args), do: call(field_pid, args)
  def call(nil, _args), do: :error

  def call(pid, args) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.call(pid, args)
    else
      :error
    end
  catch
    :exit, _reason -> :error
  end

  @doc "Makes an asynchronous cast to a character's field process."
  @spec cast(Schema.Character.t() | pid() | nil, term()) :: :ok | :error
  def cast(%Schema.Character{field_pid: field_pid}, args), do: GenServer.cast(field_pid, args)
  def cast(nil, _args), do: :error
  def cast(pid, args), do: GenServer.cast(pid, args)

  # -- npcs & mobs -----------------------------------------------------------

  @doc "Spawns a mob (field npc) on the character's field at their position."
  @spec add_mob(Schema.Character.t(), Types.Npc.t()) :: :ok
  def add_mob(%Schema.Character{} = character, %Types.Npc{} = npc) do
    send(character.field_pid, {:add_mob, npc, character.position})
  end

  @doc "Looks up an npc by object id in the character's field."
  @spec lookup_npc(Schema.Character.t(), integer()) :: {:ok, Types.FieldNpc.t()} | :error
  def lookup_npc(%Schema.Character{} = character, object_id) do
    call(character.field_pid, {:lookup_npc, object_id})
  end

  @doc "Removes an npc from its field (idempotent)."
  @spec remove_npc(Types.FieldNpc.t()) :: :ok
  def remove_npc(%Types.FieldNpc{} = field_npc) do
    field_pid = Process.whereis(field_npc.field)
    send(field_pid, {:remove_npc, field_npc})
  end

  @doc "Applies damage to a field npc on the character's field."
  @spec inflict_dmg(Schema.Character.t(), map(), integer()) ::
          {:ok, Types.FieldNpc.t()} | :error
  def inflict_dmg(attacker, dmg, object_id) do
    call(attacker, {:inflict_dmg, attacker, dmg, object_id})
  end

  @doc "Applies a skill cast's on-hit effects to a field npc."
  @spec apply_skill_effects(Schema.Character.t(), map(), integer()) :: :ok
  def apply_skill_effects(character, skill_cast, mob_object_id) do
    call(character.field_pid, {:apply_skill_effects, skill_cast, mob_object_id})
  end

  # -- items -----------------------------------------------------------------

  @doc """
  Drops an item from a field npc (mob) into the field, locked to the given
  receiver when one is provided (nil for shared/unlocked drops).
  """
  @spec add_mob_drop(Types.FieldNpc.t(), Schema.Item.t(), Schema.Character.t() | nil) ::
          :ok | :error
  def add_mob_drop(%Types.FieldNpc{} = field_npc, item, receiver \\ nil) do
    cast(field_npc.field, {:add_mob_drop, field_npc, item, receiver})
  end

  @doc "Drops an item from a character's inventory into the field."
  @spec drop_item(Schema.Character.t(), Schema.Item.t()) :: :ok | :error
  def drop_item(%Schema.Character{} = character, item) do
    cast(character.field_pid, {:drop_item, character, item})
  end

  @doc "Drops an item at a fixed position instead of at the character's feet."
  @spec drop_item(Schema.Character.t(), Schema.Item.t(), map()) :: :ok | :error
  def drop_item(%Schema.Character{} = character, item, position) do
    cast(character.field_pid, {:drop_item, character, item, position})
  end

  @doc "Picks up a field item by object id."
  @spec pickup_item(Schema.Character.t(), integer()) ::
          {:ok, Schema.Item.t()} | {:error, atom()}
  def pickup_item(%Schema.Character{} = character, object_id) do
    call(character.field_pid, {:pickup_item, character, object_id})
  end

  # -- buffs -----------------------------------------------------------------

  @doc "Applies a skill's buff from a skill cast to its caster."
  @spec add_buff(Schema.Character.t(), map(), map()) :: {:ok, map()} | :error
  def add_buff(character, skill_cast, skill) do
    call(character.field_pid, {:add_buff, skill_cast, skill, character})
  end

  @doc """
  Applies an additional-effect buff to the character (caster = owner).

  ## Options

    * `:overlap_count` — initial stack count
    * `:duration_tick` / `:elapsed_tick` — override the effect's window
      (stored-buff restores)
  """
  @spec add_effect_buff(Schema.Character.t(), integer(), integer(), keyword()) ::
          :ok | :error
  def add_effect_buff(character, effect_id, effect_level, opts \\ []) do
    call(character.field_pid, {:add_effect_buff, effect_id, effect_level, character, opts})
  end

  @doc "Applies an additional-effect buff cast by `caster` on `owner`."
  @spec add_effect_buff_for(Schema.Character.t(), Schema.Character.t(), integer(), integer()) ::
          :ok | :error
  def add_effect_buff_for(owner, caster, effect_id, effect_level) do
    call(owner.field_pid, {:add_effect_buff_for, effect_id, effect_level, caster, owner})
  end

  @doc "Whether the character currently has the given effect active, whoever cast it."
  @spec has_buff?(Schema.Character.t(), integer()) :: boolean()
  def has_buff?(%Schema.Character{} = character, effect_id) do
    call(character.field_pid, {:has_buff?, character.object_id, effect_id}) == true
  end

  @doc """
  Whether the character's field has an effect of the given event category
  active on them (the auto-fish and auto-perform conveniences, safe riding).
  """
  @spec has_buff_event?(Schema.Character.t(), atom()) :: boolean()
  def has_buff_event?(%Schema.Character{} = character, event_type) do
    call(character.field_pid, {:has_buff_event?, character.object_id, event_type}) == true
  end

  @doc "Shifts the remaining duration of the character's effect."
  @spec modify_buff_duration(Schema.Character.t(), integer(), integer()) :: :ok | :error
  def modify_buff_duration(%Schema.Character{} = character, effect_id, modify_tick) do
    call(
      character.field_pid,
      {:modify_buff_duration, character.object_id, effect_id, modify_tick}
    )
  end

  @doc "Removes a single effect from the character, whoever cast it."
  @spec remove_effect_buff(Schema.Character.t(), integer()) :: :ok | :error
  def remove_effect_buff(%Schema.Character{} = character, effect_id) do
    call(character.field_pid, {:remove_effect_buff, character.object_id, effect_id})
  end

  @doc "Removes all buffs owned by the character (e.g. on death)."
  @spec remove_owner_buffs(Schema.Character.t()) :: :ok | :error
  def remove_owner_buffs(%Schema.Character{} = character) do
    cast(character.field_pid, {:remove_owner_buffs, character.object_id})
  end

  # -- instruments -----------------------------------------------------------

  @doc "Spawns the instrument a character is playing, assigning a field object id."
  @spec add_instrument(Schema.Character.t(), Types.FieldInstrument.t()) ::
          {:ok, Types.FieldInstrument.t()} | :error
  def add_instrument(%Schema.Character{} = character, %Types.FieldInstrument{} = instrument) do
    call(character.field_pid, {:add_instrument, instrument})
  end

  @doc "Looks up the instrument a character is currently playing."
  @spec lookup_instrument(Schema.Character.t()) :: {:ok, Types.FieldInstrument.t()} | :error
  def lookup_instrument(%Schema.Character{} = character) do
    call(character.field_pid, {:lookup_instrument, character.id})
  end

  @doc "Despawns a character's instrument, returning it so callers can announce the stop."
  @spec remove_instrument(Schema.Character.t()) :: {:ok, Types.FieldInstrument.t()} | :error
  def remove_instrument(%Schema.Character{} = character) do
    call(character.field_pid, {:remove_instrument, character.id})
  end

  # -- performance stage -----------------------------------------------------

  @doc "Whether the character's field has a performance stage (the concert map)."
  @spec performance_stage?(Schema.Character.t()) :: boolean()
  def performance_stage?(%Schema.Character{} = character) do
    call(character.field_pid, :performance_stage?) == true
  end

  @doc "Claims the performance stage, announcing the concert to everyone on the map."
  @spec start_performance(Schema.Character.t()) :: :ok | :error
  def start_performance(%Schema.Character{} = character) do
    cast(character.field_pid, {:start_performance, character})
  end

  @doc "Releases the performance stage; ignored when not the current performer."
  @spec end_performance(Schema.Character.t()) :: :ok | :error
  def end_performance(%Schema.Character{} = character) do
    cast(character.field_pid, {:end_performance, character.id})
  end

  @doc "Moves the character on or off the concert stage."
  @spec toggle_stage(Schema.Character.t()) :: :ok | :error
  def toggle_stage(%Schema.Character{} = character) do
    cast(character.field_pid, {:toggle_stage, character})
  end

  @doc "Puts a character into battle stance (the field drops it after a beat)."
  @spec enter_battle_stance(Schema.Character.t()) :: :ok | :error
  def enter_battle_stance(%Schema.Character{} = character) do
    cast(character.field_pid, {:enter_battle_stance, character})
  end

  # -- tombstones ------------------------------------------------------------

  @doc """
  Adds a tombstone for a dead character, broadcasting it so other players
  can hit it to revive the owner.
  """
  @spec add_tombstone(Schema.Character.t()) :: :ok | :error
  def add_tombstone(%Schema.Character{} = character) do
    cast(character.field_pid, {:add_tombstone, character})
  end

  @doc "Removes a character's tombstone from the field (on field leave)."
  @spec remove_tombstone(Schema.Character.t()) :: :ok | :error
  def remove_tombstone(%Schema.Character{} = character) do
    cast(character.field_pid, {:remove_tombstone, character.id})
  end

  @doc """
  Broadcasts a tombstone with zero hits remaining and removes it (when its
  owner revives); clients tear down the tombstone entity.
  """
  @spec clear_tombstone(Schema.Character.t()) :: :ok | :error
  def clear_tombstone(%Schema.Character{} = character) do
    cast(character.field_pid, {:clear_tombstone, character.id})
  end

  @doc """
  Registers a hit against a dead character's tombstone; reduces the hits
  remaining and revives the owner when it reaches zero.
  """
  @spec hit_tombstone(Schema.Character.t(), integer(), integer()) :: :ok | :error
  def hit_tombstone(%Schema.Character{} = character, object_id, hits) do
    call(character.field_pid, {:hit_tombstone, object_id, hits})
  end

  # -- banners ---------------------------------------------------------------

  @doc "Reserves banner slots for a character."
  @spec reserve_banner_slots(Schema.Character.t(), integer(), [map()]) ::
          {:ok, [map()]} | :error
  def reserve_banner_slots(%Schema.Character{} = character, banner_id, reservations) do
    call(character.field_pid, {:reserve_banner_slots, character, banner_id, reservations})
  end

  @doc "Attaches artwork to the character's own empty banner slots."
  @spec attach_banner(Schema.Character.t(), integer(), [integer()], map()) ::
          {:ok, map()} | :error
  def attach_banner(%Schema.Character{} = character, banner_id, slot_ids, ugc) do
    call(character.field_pid, {:attach_banner, character, banner_id, slot_ids, ugc})
  end

  @doc "Confirms an artwork upload, storing the rendered image on its slot."
  @spec confirm_banner(Schema.Character.t(), integer(), String.t()) :: {:ok, map()} | :error
  def confirm_banner(%Schema.Character{} = character, resource_id, path) do
    call(character.field_pid, {:confirm_banner, resource_id, path})
  end

  @doc "Lists every banner of the character's field."
  @spec banners(Schema.Character.t()) :: [map()] | :error
  def banners(%Schema.Character{} = character), do: call(character.field_pid, :banners)

  # -- liftables ---------------------------------------------------------------

  @doc "The character picks up a liftable prop with the interact key."
  @spec pickup_liftable(Schema.Character.t(), String.t()) :: :ok | :error
  def pickup_liftable(%Schema.Character{} = character, uuid) do
    call(character.field_pid, {:pickup_liftable, character.id, uuid})
  end

  @doc "The character places a held liftable at a grid tile."
  @spec place_liftable(Schema.Character.t(), tuple(), integer(), integer()) :: :ok | :error
  def place_liftable(%Schema.Character{} = character, grid, item_id, rotation) do
    call(character.field_pid, {:place_liftable, character.id, grid, item_id, rotation})
  end

  # -- interact objects & region skills ---------------------------------------

  @doc """
  Completes a player's interaction with a field interact object. Returns
  `{:ok, object}` when the object exists so callers can progress
  interact-object quest conditions and run gathering.
  """
  @spec interact_object(Schema.Character.t(), String.t()) :: {:ok, map()} | :error
  def interact_object(%Schema.Character{} = character, uuid) do
    call(character.field_pid, {:interact_object, character, uuid})
  end

  @doc "Adds a region skill (skill effect zone) to the character's field."
  @spec add_region_skill(Schema.Character.t(), map()) :: {:ok, integer()} | {:error, atom()}
  def add_region_skill(%Schema.Character{} = character, skill_cast) do
    call(character.field_pid, {:add_region_skill, skill_cast})
  end

  @doc "Allocates a field-unique object id (guide objects, effects, ...)."
  @spec next_object_id(Schema.Character.t()) :: {:ok, integer()} | :error
  def next_object_id(%Schema.Character{} = character) do
    call(character.field_pid, :next_object_id)
  end

  # -- trigger scripts ---------------------------------------------------------

  @doc "Feeds a character's live position to the trigger conditions."
  @spec user_position(Schema.Character.t(), map()) :: :ok | :error
  def user_position(%Schema.Character{} = character, position) do
    cast(character.field_pid, {:user_position, character.id, position})
  end

  @doc "Applies a client widget update (guide events, finished scene movies)."
  @spec update_widget(Schema.Character.t(), atom(), integer()) :: :ok | :error
  def update_widget(%Schema.Character{} = character, widget_key, arg) do
    call(character.field_pid, {:update_widget, widget_key, arg})
  end

  @doc "The player pressed the cutscene skip button."
  @spec skip_cutscene(Schema.Character.t()) :: :ok | :error
  def skip_cutscene(%Schema.Character{} = character) do
    call(character.field_pid, {:skip_cutscene})
  end

  #
  # GenServer
  #

  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    instance = character.field_instance || 0
    field_name = field_name(map_id, channel_id, instance)

    {local_id_counter, portals} = __MODULE__.Portal.load(map_id, @local_id_counter)
    interactable = __MODULE__.InteractObject.load(map_id)

    state =
      %{
        buffs: %{},
        banners: __MODULE__.Banner.load(map_id),
        channel_id: channel_id,
        instance: instance,
        local_id_counter: local_id_counter,
        interactable: interactable,
        instruments: %{},
        items: %{},
        map_id: map_id,
        mob_gates: Storage.Maps.get_mob_gates(map_id),
        opened_gates: MapSet.new(),
        hidden_meshes: [],
        player_positions: %{},
        mounts: %{},
        npcs: %{},
        npc_spawns: %{},
        performance: nil,
        players: %{},
        portals: portals,
        regions: %{},
        sessions: %{},
        stage: MapSet.new(),
        tombstones: %{},
        topic: field_name
      }
      |> __MODULE__.Liftable.init_liftables()
      |> __MODULE__.Trigger.init_triggers()

    send(self(), :load_npc_spawns)
    send(self(), :tick_npcs)
    send(self(), :send_updates)
    send(self(), :tick_banners)

    {:ok, state, {:continue, {:add_character, character}}}
  end

  def handle_continue({:add_character, character}, state),
    do: {:noreply, __MODULE__.Character.add_character(character, state)}

  def handle_call({:add_character, character}, _from, state),
    do: {:reply, {:ok, self()}, __MODULE__.Character.add_character(character, state)}

  def handle_call({:remove_character, character}, _from, state) do
    send(self(), :maybe_stop)

    {:reply, :ok, __MODULE__.Character.remove_character(character, state)}
  end

  def handle_call({:update_widget, widget_key, arg}, _from, state) do
    {:reply, :ok, __MODULE__.Trigger.update_widget(state, widget_key, arg)}
  end

  def handle_call({:skip_cutscene}, _from, state) do
    {:reply, :ok, __MODULE__.Trigger.skip_cutscene(state)}
  end

  def handle_call({:pickup_liftable, character_id, uuid}, _from, state) do
    {:reply, :ok, __MODULE__.Liftable.pickup(state, character_id, uuid)}
  end

  def handle_call({:place_liftable, character_id, grid, item_id, rotation}, _from, state) do
    {:reply, :ok, __MODULE__.Liftable.place(state, character_id, grid, item_id, rotation)}
  end

  def handle_call({:pickup_item, character, object_id}, _from, state) do
    case Map.get(state.items, object_id) do
      nil ->
        {:reply, :error, state}

      item ->
        {:reply, {:ok, item}, __MODULE__.Item.pickup_item(character, item, state)}
    end
  end

  def handle_call({:hit_tombstone, object_id, hits}, _from, state) do
    case __MODULE__.Tombstone.hit(object_id, hits, state) do
      {:ok, state} ->
        {:reply, :ok, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:add_instrument, instrument}, _from, state) do
    {instrument, state} = __MODULE__.Instrument.add(instrument, state)
    {:reply, {:ok, instrument}, state}
  end

  def handle_call(:next_object_id, _from, state) do
    {object_id, state} = next_local_id(state)
    {:reply, {:ok, object_id}, state}
  end

  def handle_call({:lookup_instrument, character_id}, _from, state) do
    case __MODULE__.Instrument.get(character_id, state) do
      nil -> {:reply, :error, state}
      instrument -> {:reply, {:ok, instrument}, state}
    end
  end

  def handle_call({:remove_instrument, character_id}, _from, state) do
    case __MODULE__.Instrument.get(character_id, state) do
      nil -> {:reply, :error, state}
      instrument -> {:reply, {:ok, instrument}, __MODULE__.Instrument.remove(character_id, state)}
    end
  end

  def handle_call({:reserve_banner_slots, character, banner_id, reservations}, _from, state) do
    case __MODULE__.Banner.reserve(character, banner_id, reservations, state) do
      {:ok, slots, state} -> {:reply, {:ok, slots}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:attach_banner, character, banner_id, slot_ids, ugc}, _from, state) do
    case __MODULE__.Banner.attach(character, banner_id, slot_ids, ugc, state) do
      {:ok, banner, state} -> {:reply, {:ok, banner}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:confirm_banner, resource_id, path}, _from, state) do
    case __MODULE__.Banner.confirm(resource_id, path, state) do
      {:ok, banner, state} -> {:reply, {:ok, banner}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call(:banners, _from, state), do: {:reply, __MODULE__.Banner.all(state), state}

  def handle_call(:performance_stage?, _from, state),
    do: {:reply, __MODULE__.PerformanceStage.stage?(state), state}

  def handle_call({:interact_object, character, uuid}, _from, state) do
    case __MODULE__.InteractObject.react(character, uuid, state) do
      {:ok, object, state} ->
        {:reply, {:ok, object}, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:add_region_skill, skill_cast}, _from, state),
    do: {:reply, :ok, __MODULE__.RegionSkill.add(skill_cast, state)}

  def handle_call({:add_buff, skill_cast, skill, character}, _from, state) do
    case __MODULE__.Buff.add_buff(skill_cast, skill, character, state) do
      {nil, state} ->
        {:reply, :error, state}

      {buff, state} ->
        {:reply, {:ok, buff}, state}
    end
  end

  def handle_call({:add_effect_buff, effect_id, effect_level, character}, from, state),
    do: handle_call({:add_effect_buff, effect_id, effect_level, character, []}, from, state)

  def handle_call({:add_effect_buff, effect_id, effect_level, character, opts}, _from, state) do
    {_buff, state} =
      __MODULE__.Buff.add_effect_buff(effect_id, effect_level, character, state, 0, opts)

    {:reply, :ok, state}
  end

  def handle_call(
        {:add_effect_buff_for, effect_id, effect_level, caster, owner},
        _from,
        state
      ) do
    {_buff, state} =
      __MODULE__.Buff.add_effect_buff_for(effect_id, effect_level, caster, owner, state)

    {:reply, :ok, state}
  end

  def handle_call({:has_buff?, owner_object_id, effect_id}, _from, state),
    do: {:reply, __MODULE__.Buff.owner_has_buff?(owner_object_id, effect_id, state), state}

  def handle_call({:has_buff_event?, owner_object_id, event_type}, _from, state),
    do: {:reply, __MODULE__.Buff.owner_has_buff_event?(owner_object_id, event_type, state), state}

  def handle_call({:modify_buff_duration, owner_object_id, effect_id, modify_tick}, _from, state),
    do:
      {:reply, :ok,
       __MODULE__.Buff.modify_duration(owner_object_id, effect_id, modify_tick, state)}

  def handle_call({:remove_effect_buff, owner_object_id, effect_id}, _from, state),
    do: {:reply, :ok, __MODULE__.Buff.remove_owner_effect(owner_object_id, effect_id, state)}

  def handle_call({:lookup_npc, object_id}, _from, state) do
    case Map.get(state.npcs, object_id) do
      nil -> {:reply, :error, state}
      npc -> {:reply, {:ok, npc}, state}
    end
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}, object_id}, _from, state) do
    case __MODULE__.Npc.damage(state, attacker, dmg, object_id) do
      {:ok, field_npc, state} ->
        {:reply, {:ok, field_npc}, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:apply_skill_effects, skill_cast, mob_id}, _from, state),
    do: {:reply, :ok, __MODULE__.Npc.apply_skill_effects(state, skill_cast, mob_id)}

  def handle_cast({:drop_item, source, item}, state),
    do: {:noreply, __MODULE__.Item.drop_item(source, item, state)}

  # trigger conditions detect users by their live position
  def handle_cast({:user_position, character_id, position}, state) do
    {:noreply, __MODULE__.Trigger.track_position(state, character_id, position)}
  end

  def handle_cast({:drop_item, source, item, position}, state),
    do: {:noreply, __MODULE__.Item.drop_item(source, item, position, state)}

  def handle_cast(
        {:add_mob_drop, %Types.FieldNpc{} = mob, %Schema.Item{} = item, receiver},
        state
      ),
      do: {:noreply, __MODULE__.Item.add_mob_drop(mob, item, receiver, state)}

  # a dead player's tombstone is announced with its hit counts so clients can
  # render the revive gauge and hit it; the owner is keyed by character id for
  # the revive lookup
  def handle_cast({:add_tombstone, character}, state),
    do: {:noreply, __MODULE__.Tombstone.add(character, state)}

  def handle_cast({:clear_tombstone, character_id}, state),
    do: {:noreply, __MODULE__.Tombstone.clear(character_id, state)}

  def handle_cast({:remove_tombstone, character_id}, state),
    do: {:noreply, __MODULE__.Tombstone.remove(character_id, state)}

  # buffs die with their owner; remove every buff owned by the object id
  def handle_cast({:remove_owner_buffs, owner_object_id}, state),
    do: {:noreply, __MODULE__.Buff.remove_owner_buffs(owner_object_id, state)}

  def handle_cast({:start_performance, character}, state),
    do: {:noreply, __MODULE__.PerformanceStage.start(character, state)}

  def handle_cast({:end_performance, character_id}, state),
    do: {:noreply, __MODULE__.PerformanceStage.stop(character_id, state)}

  def handle_cast({:toggle_stage, character}, state),
    do: {:noreply, __MODULE__.PerformanceStage.toggle_stage(character, state)}

  def handle_cast({:enter_battle_stance, character}, state) do
    # battle-start packets are emitted by the cast handler in order; the
    # field process only schedules the eventual stance drop
    Process.send_after(self(), {:leave_battle_stance, character}, 5_000)
    {:noreply, state}
  end

  #
  # NPCs
  #

  def handle_info(:load_npc_spawns, state) do
    # the trigger machines must not consume their first states until every
    # spawn point doc is registered, so ticking is gated on this counter
    npc_count = length(Storage.Maps.get_npc_spawns(state.map_id))
    mob_count = length(Storage.Maps.get_mob_spawns(state.map_id))
    state = Map.put(state, :spawn_docs_pending, npc_count + mob_count)

    __MODULE__.Npc.load_npc_spawns(state)
    __MODULE__.Npc.load_mob_spawns(state)
    {:noreply, state}
  end

  def handle_info({:add_npc_spawn, npc_spawn, npc_ids}, state) do
    state = __MODULE__.Npc.load_spawn(state, npc_spawn, npc_ids)
    pending = Map.get(state, :spawn_docs_pending, 1) - 1
    {:noreply, Map.put(state, :spawn_docs_pending, max(pending, 0))}
  end

  def handle_info({:add_npc, npc_id, npc_spawn}, state),
    do: {:noreply, __MODULE__.Npc.load_npc(state, npc_id, npc_spawn)}

  def handle_info({:add_mob, %Types.Npc{} = npc, position}, state),
    do: {:noreply, __MODULE__.Npc.load_npc(state, npc, %{position: position, rotation: nil})}

  def handle_info({:remove_npc, field_npc}, state) do
    # destroy_monster and corpse timers can race; removal is idempotent
    case Map.get(state.npcs, field_npc.object_id) do
      %Types.FieldNpc{} ->
        broadcast(
          field_npc.field,
          Packets.FieldRemoveNpc.bytes(field_npc.object_id)
        )

        broadcast(field_npc.field, Packets.ProxyGameObj.remove_npc(field_npc))

        {:noreply, __MODULE__.Npc.remove_npc(field_npc, state)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:release_guide_hold, state),
    do: {:noreply, __MODULE__.Trigger.release_guide_hold(state)}

  def handle_info(:tick_npcs, state) do
    Process.send_after(self(), :tick_npcs, @npc_tick_intval)

    if Map.get(state, :spawn_docs_pending, 0) > 0 do
      {:noreply, state}
    else
      state = __MODULE__.InteractObject.tick(state)
      state = __MODULE__.Trigger.tick(state)
      state = __MODULE__.Npc.tick(state)
      {:noreply, __MODULE__.Liftable.expire_placed(state)}
    end
  end

  def handle_info({:region_tick, source_id}, state),
    do: {:noreply, __MODULE__.RegionSkill.maybe_tick(source_id, state)}

  def handle_info({:remove_region_skill, source_id}, state) do
    broadcast(state.topic, Packets.RegionSkill.remove(source_id))
    {:noreply, state}
  end

  def handle_info({:remove_status, status}, state) do
    broadcast(state.topic, Packets.Buff.send(:remove, status))
    {:noreply, state}
  end

  def handle_info({:buff_tick, buff_id}, state) do
    state = __MODULE__.Buff.tick(buff_id, state)
    {:noreply, state}
  end

  def handle_info({:remove_buff, buff_id}, state) do
    state = __MODULE__.Buff.remove_buff(buff_id, state)
    {:noreply, state}
  end

  def handle_info({:leave_battle_stance, character}, state) do
    __MODULE__.Character.leave_battle_stance(character)
    {:noreply, state}
  end

  def handle_info({:end_performance, character_id}, state),
    do: {:noreply, __MODULE__.PerformanceStage.release(character_id, state)}

  def handle_info(:send_updates, state) do
    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, __MODULE__.Character.send_updates(state)}
  end

  def handle_info(:tick_banners, state) do
    Process.send_after(self(), :tick_banners, @banner_tick_intval)
    {state, changed} = __MODULE__.Banner.activate(state)
    Enum.each(changed, &broadcast(state.topic, Packets.Ugc.activate_banner(&1)))
    {:noreply, state}
  end

  def handle_info(:maybe_stop, state) do
    if Enum.empty?(state.sessions) do
      Logger.info("Field #{state.map_id} @ Channel #{state.channel_id} is empty. Stopping.")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(data, state) do
    Logger.warning("[Field] Unknown message: #{inspect(data)}")
    {:noreply, state}
  end
end
