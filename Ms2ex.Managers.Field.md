# `Ms2ex.Managers.Field`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field.ex#L1)

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

# `add_buff`

```elixir
@spec add_buff(Ms2ex.Schema.Character.t(), map(), map()) :: {:ok, map()} | :error
```

Applies a skill's buff from a skill cast to its caster.

# `add_effect_buff`

```elixir
@spec add_effect_buff(Ms2ex.Schema.Character.t(), integer(), integer(), keyword()) ::
  :ok | :error
```

Applies an additional-effect buff to the character (caster = owner).

## Options

  * `:overlap_count` — initial stack count
  * `:duration_tick` / `:elapsed_tick` — override the effect's window
    (stored-buff restores)

# `add_effect_buff_for`

```elixir
@spec add_effect_buff_for(
  Ms2ex.Schema.Character.t(),
  Ms2ex.Schema.Character.t(),
  integer(),
  integer()
) ::
  :ok | :error
```

Applies an additional-effect buff cast by `caster` on `owner`.

# `add_instrument`

```elixir
@spec add_instrument(Ms2ex.Schema.Character.t(), Ms2ex.Types.FieldInstrument.t()) ::
  {:ok, Ms2ex.Types.FieldInstrument.t()} | :error
```

Spawns the instrument a character is playing, assigning a field object id.

# `add_mob`

```elixir
@spec add_mob(Ms2ex.Schema.Character.t(), Ms2ex.Types.Npc.t()) :: :ok
```

Spawns a mob (field npc) on the character's field at their position.

# `add_mob_drop`

```elixir
@spec add_mob_drop(
  Ms2ex.Types.FieldNpc.t(),
  Ms2ex.Schema.Item.t(),
  Ms2ex.Schema.Character.t() | nil
) ::
  :ok | :error
```

Drops an item from a field npc (mob) into the field, locked to the given
receiver when one is provided (nil for shared/unlocked drops).

# `add_region_skill`

```elixir
@spec add_region_skill(Ms2ex.Schema.Character.t(), map()) ::
  {:ok, integer()} | {:error, atom()}
```

Adds a region skill (skill effect zone) to the character's field.

# `add_tombstone`

```elixir
@spec add_tombstone(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Adds a tombstone for a dead character, broadcasting it so other players
can hit it to revive the owner.

# `apply_skill_effects`

```elixir
@spec apply_skill_effects(Ms2ex.Schema.Character.t(), map(), integer()) :: :ok
```

Applies a skill cast's on-hit effects to a field npc.

# `assign_instance`

```elixir
@spec assign_instance(Ms2ex.Schema.Character.t()) :: Ms2ex.Schema.Character.t()
```

Binds the character to a field instance: a pending `change_map` instance
(fresh allocation from `change_field/2,4`) wins, an existing stamp is
kept while the character stays on the same field, anything else
allocates.

# `attach_banner`

```elixir
@spec attach_banner(Ms2ex.Schema.Character.t(), integer(), [integer()], map()) ::
  {:ok, map()} | :error
```

Attaches artwork to the character's own empty banner slots.

# `banners`

```elixir
@spec banners(Ms2ex.Schema.Character.t()) :: [map()] | :error
```

Lists every banner of the character's field.

# `broadcast`

```elixir
@spec broadcast(Ms2ex.Schema.Character.t() | term(), binary()) :: :ok
```

Broadcasts a packet to every character on a field.

# `broadcast_from`

```elixir
@spec broadcast_from(Ms2ex.Schema.Character.t(), binary(), pid()) :: :ok
```

Broadcasts a packet to every character on the character's field except
the given process.

# `broadcast_stats`

```elixir
@spec broadcast_stats(Ms2ex.Schema.Character.t()) :: :ok
```

Sends the full stat set to the character and the compact player stat
update to every other character in the same field.

# `call`

```elixir
@spec call(Ms2ex.Schema.Character.t() | pid() | nil, term()) :: term() | :error
```

Makes a synchronous call to a character's field process; `:error` when
the character has no field or the call fails.

# `cast`

```elixir
@spec cast(Ms2ex.Schema.Character.t() | pid() | nil, term()) :: :ok | :error
```

Makes an asynchronous cast to a character's field process.

# `change_field`

```elixir
@spec change_field(Ms2ex.Schema.Character.t(), integer()) :: :ok | {:error, term()}
```

Changes a character's field to a new map, using the map's default spawn
point.

# `change_field`

```elixir
@spec change_field(Ms2ex.Schema.Character.t(), integer(), map(), map()) ::
  :ok | {:error, term()}
```

Changes a character's field to a new map at a specific position.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_tombstone`

```elixir
@spec clear_tombstone(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Broadcasts a tombstone with zero hits remaining and removes it (when its
owner revives); clients tear down the tombstone entity.

# `confirm_banner`

```elixir
@spec confirm_banner(Ms2ex.Schema.Character.t(), integer(), String.t()) ::
  {:ok, map()} | :error
```

Confirms an artwork upload, storing the rendered image on its slot.

# `drop_item`

```elixir
@spec drop_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) :: :ok | :error
```

Drops an item from a character's inventory into the field.

# `drop_item`

```elixir
@spec drop_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t(), map()) ::
  :ok | :error
```

Drops an item at a fixed position instead of at the character's feet.

# `end_performance`

```elixir
@spec end_performance(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Releases the performance stage; ignored when not the current performer.

# `enter`

```elixir
@spec enter(Ms2ex.Schema.Character.t()) :: :ok | {:ok, pid()} | {:error, term()}
```

Adds a character to a field, creating the field process if it doesn't
exist. Returns `{:ok, pid}` for a fresh field, `{:ok, field_pid}` when the
character joined an existing one.

# `enter_battle_stance`

```elixir
@spec enter_battle_stance(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Puts a character into battle stance (the field drops it after a beat).

# `field_name`

```elixir
@spec field_name(Ms2ex.Schema.Character.t()) :: atom()
```

Field process name / PubSub topic for the field a character is on. A
missing instance id is the map's shared field (instance 0).

# `field_name`

```elixir
@spec field_name(integer(), integer(), integer() | nil) :: atom()
```

Generates a unique field process name from a map ID, channel ID and
instance ID. Instance 0 is the shared field of the map on the channel;
instanced maps (see `Storage.Tables.InstanceFields`) carry their own id.

# `handle_continue`

# `has_buff?`

```elixir
@spec has_buff?(Ms2ex.Schema.Character.t(), integer()) :: boolean()
```

Whether the character currently has the given effect active, whoever cast it.

# `has_buff_event?`

```elixir
@spec has_buff_event?(Ms2ex.Schema.Character.t(), atom()) :: boolean()
```

Whether the character's field has an effect of the given event category
active on them (the auto-fish and auto-perform conveniences, safe riding).

# `hit_tombstone`

```elixir
@spec hit_tombstone(Ms2ex.Schema.Character.t(), integer(), integer()) :: :ok | :error
```

Registers a hit against a dead character's tombstone; reduces the hits
remaining and revives the owner when it reaches zero.

# `inflict_dmg`

```elixir
@spec inflict_dmg(Ms2ex.Schema.Character.t(), map(), integer()) ::
  {:ok, Ms2ex.Types.FieldNpc.t()} | :error
```

Applies damage to a field npc on the character's field.

# `init`

# `instance_id`

```elixir
@spec instance_id(integer()) :: integer()
```

The field instance id a character enters for the map: solo maps
(tutorials, quest instances) run one private field per entry, so a
fresh id is allocated per call; every other map — including
channel-scale ones — shares a single field per channel (id 0).

# `interact_object`

```elixir
@spec interact_object(Ms2ex.Schema.Character.t(), String.t()) :: {:ok, map()} | :error
```

Completes a player's interaction with a field interact object. Returns
`{:ok, object}` when the object exists so callers can progress
interact-object quest conditions and run gathering.

# `leave`

```elixir
@spec leave(Ms2ex.Schema.Character.t()) :: :ok | {:error, term()}
```

Removes a character from their current field.

# `lookup_instrument`

```elixir
@spec lookup_instrument(Ms2ex.Schema.Character.t()) ::
  {:ok, Ms2ex.Types.FieldInstrument.t()} | :error
```

Looks up the instrument a character is currently playing.

# `lookup_npc`

```elixir
@spec lookup_npc(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Types.FieldNpc.t()} | :error
```

Looks up an npc by object id in the character's field.

# `modify_buff_duration`

```elixir
@spec modify_buff_duration(Ms2ex.Schema.Character.t(), integer(), integer()) ::
  :ok | :error
```

Shifts the remaining duration of the character's effect.

# `next_local_id`

Allocates the next field-local object id (npcs, items, effects, ...).

# `next_object_id`

```elixir
@spec next_object_id(Ms2ex.Schema.Character.t()) :: {:ok, integer()} | :error
```

Allocates a field-unique object id (guide objects, effects, ...).

# `performance_stage?`

```elixir
@spec performance_stage?(Ms2ex.Schema.Character.t()) :: boolean()
```

Whether the character's field has a performance stage (the concert map).

# `pickup_item`

```elixir
@spec pickup_item(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, atom()}
```

Picks up a field item by object id.

# `pickup_liftable`

```elixir
@spec pickup_liftable(Ms2ex.Schema.Character.t(), String.t()) :: :ok | :error
```

The character picks up a liftable prop with the interact key.

# `place_liftable`

```elixir
@spec place_liftable(Ms2ex.Schema.Character.t(), tuple(), integer(), integer()) ::
  :ok | :error
```

The character places a held liftable at a grid tile.

# `remove_effect_buff`

```elixir
@spec remove_effect_buff(Ms2ex.Schema.Character.t(), integer()) :: :ok | :error
```

Removes a single effect from the character, whoever cast it.

# `remove_instrument`

```elixir
@spec remove_instrument(Ms2ex.Schema.Character.t()) ::
  {:ok, Ms2ex.Types.FieldInstrument.t()} | :error
```

Despawns a character's instrument, returning it so callers can announce the stop.

# `remove_npc`

```elixir
@spec remove_npc(Ms2ex.Types.FieldNpc.t()) :: :ok
```

Removes an npc from its field (idempotent).

# `remove_owner_buffs`

```elixir
@spec remove_owner_buffs(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Removes all buffs owned by the character (e.g. on death).

# `remove_tombstone`

```elixir
@spec remove_tombstone(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Removes a character's tombstone from the field (on field leave).

# `reserve_banner_slots`

```elixir
@spec reserve_banner_slots(Ms2ex.Schema.Character.t(), integer(), [map()]) ::
  {:ok, [map()]} | :error
```

Reserves banner slots for a character.

# `return_map_id`

```elixir
@spec return_map_id(integer()) :: integer()
```

The map a character who quit on `map_id` should return to: the map's
`enter_return_id` when it declares one, the map itself otherwise.

# `skip_cutscene`

```elixir
@spec skip_cutscene(Ms2ex.Schema.Character.t()) :: :ok | :error
```

The player pressed the cutscene skip button.

# `start_performance`

```elixir
@spec start_performance(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Claims the performance stage, announcing the concert to everyone on the map.

# `subscribe`

```elixir
@spec subscribe(Ms2ex.Schema.Character.t()) :: :ok | {:error, term()}
```

Subscribes the current process to a character's field events.

# `toggle_stage`

```elixir
@spec toggle_stage(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Moves the character on or off the concert stage.

# `unsubscribe`

```elixir
@spec unsubscribe(Ms2ex.Schema.Character.t()) :: :ok
```

Unsubscribes the current process from a character's field events.

# `update_widget`

```elixir
@spec update_widget(Ms2ex.Schema.Character.t(), atom(), integer()) :: :ok | :error
```

Applies a client widget update (guide events, finished scene movies).

# `user_position`

```elixir
@spec user_position(Ms2ex.Schema.Character.t(), map()) :: :ok | :error
```

Feeds a character's live position to the trigger conditions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
