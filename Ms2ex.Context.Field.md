# `Ms2ex.Context.Field`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/field.ex#L1)

Context module for field-related operations.

This module provides functions for managing field interactions, including
character movement between maps, object and mob interactions, item pickups,
and field broadcasts.

# `add_mob`

```elixir
@spec add_mob(Ms2ex.Schema.Character.t(), %{type: :npc}) :: :ok
```

Adds a mob (Field NPC) to the field at the character's position.

## Examples

    iex> add_mob(character, npc)
    :ok

# `add_mob_drop`

```elixir
@spec add_mob_drop(
  Ms2ex.Types.FieldNpc.t(),
  Ms2ex.Schema.Item.t(),
  Ms2ex.Schema.Character.t() | nil
) ::
  :ok | :error
```

Drops an item from a Field NPC (mob) into the field, locked to the given
receiver when one is provided (nil for shared/unlocked drops).

## Examples

    iex> add_mob_drop(field_npc, item)
    :ok

# `add_object`

```elixir
@spec add_object(Ms2ex.Schema.Character.t(), map()) ::
  {:ok, integer()} | {:error, atom()}
```

Adds an object to the field.

## Examples

    iex> add_object(character, object)
    {:ok, object_id}

# `add_region_skill`

```elixir
@spec add_region_skill(Ms2ex.Schema.Character.t(), map()) ::
  {:ok, integer()} | {:error, atom()}
```

Adds a region skill (Skill effect) to the field.

## Examples

    iex> add_region_skill(character, region_skill)
    {:ok, region_skill_id}

# `add_tombstone`

```elixir
@spec add_tombstone(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Adds a tombstone for a dead character to the field, broadcasting it to the
field so other players can hit it to revive the owner.

## Examples

    iex> add_tombstone(character)
    :ok

# `broadcast`

```elixir
@spec broadcast(Ms2ex.Schema.Character.t() | term(), binary()) :: :ok
```

Broadcasts a packet to all characters in the same field as the given character.

## Examples

    iex> broadcast(character, packet)
    :ok

    iex> broadcast(:field_123, packet)
    :ok

# `broadcast_from`

```elixir
@spec broadcast_from(Ms2ex.Schema.Character.t(), binary(), pid()) :: :ok
```

Broadcasts a packet to all characters in the same field as the given character,
except for the specified process.

## Examples

    iex> broadcast_from(character, packet, self())
    :ok

# `broadcast_stats`

```elixir
@spec broadcast_stats(Ms2ex.Schema.Character.t()) :: :ok
```

Sends the full stat set to the character and the compact player stat update
to every other character in the same field.

# `call`

```elixir
@spec call(Ms2ex.Schema.Character.t() | pid() | nil, term()) :: term() | :error
```

Makes a synchronous call to a field process.

## Examples

    iex> call(character, {:action, arg})
    :ok

    iex> call(nil, args)
    :error

# `cancel_battle_stance`

```elixir
@spec cancel_battle_stance(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Cancels a character's battle stance.

## Examples

    iex> cancel_battle_stance(character)
    :ok

# `cast`

```elixir
@spec cast(Ms2ex.Schema.Character.t() | pid() | nil, term()) :: :ok | :error
```

Makes an asynchronous cast to a field process.

## Examples

    iex> cast(character, {:action, arg})
    :ok

    iex> cast(nil, args)
    :error

# `change_field`

```elixir
@spec change_field(Ms2ex.Schema.Character.t(), integer()) :: :ok | {:error, term()}
```

Changes a character's field to a new map, using the map's default spawn point.

## Examples

    iex> change_field(character, 2000)
    :ok

# `change_field`

```elixir
@spec change_field(Ms2ex.Schema.Character.t(), integer(), map(), map()) ::
  :ok | {:error, term()}
```

Changes a character's field to a new map with a specific position and rotation.

## Examples

    iex> change_field(character, 2000, %{x: 100, y: 200, z: 0}, %{x: 0, y: 0, z: 0})
    :ok

# `drop_item`

```elixir
@spec drop_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) :: :ok | :error
```

Drops an item from a character's inventory into the field.

## Examples

    iex> drop_item(character, item)
    :ok

# `enter`

```elixir
@spec enter(Ms2ex.Schema.Character.t()) :: :ok | {:ok, pid()} | {:error, term()}
```

Adds a character to a field, creating the field process if it doesn't exist.

## Examples

    iex> enter(character)
    {:ok, pid}

    iex> enter(character) # when field already exists
    :ok

# `enter_battle_stance`

```elixir
@spec enter_battle_stance(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Puts a character into battle stance.

## Examples

    iex> enter_battle_stance(character)
    :ok

# `field_name`

```elixir
@spec field_name(integer(), integer()) :: atom()
```

Generates a unique field name from a map ID and channel ID.

## Examples

    iex> field_name(2000, 1)
    :"field:2000:channel:1"

# `hit_tombstone`

```elixir
@spec hit_tombstone(Ms2ex.Schema.Character.t(), integer(), integer()) :: :ok | :error
```

Registers a hit against a dead character's tombstone; reduces the hits
remaining and revives the owner when it reaches zero.

## Examples

    iex> hit_tombstone(character, object_id, hits)
    :ok

# `leave`

```elixir
@spec leave(Ms2ex.Schema.Character.t()) :: :ok | {:error, term()}
```

Removes a character from their current field.

## Examples

    iex> leave(character)
    :ok

# `lookup_npc`

```elixir
@spec lookup_npc(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Types.FieldNpc.t()} | :error
```

Looks up an NPC by object id in the character's field.

## Examples

    iex> lookup_npc(character, 10_000_001)
    {:ok, %FieldNpc{}}

# `pickup_item`

```elixir
@spec pickup_item(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, atom()}
```

Picks up an item from the field.

## Examples

    iex> pickup_item(character, object_id)
    {:ok, item}

# `remove_npc`

```elixir
@spec remove_npc(Ms2ex.Types.FieldNpc.t()) :: :ok
```

Removes an NPC from the field.

## Examples

    iex> remove_npc(field_npc)
    :ok

# `remove_owner_buffs`

```elixir
@spec remove_owner_buffs(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Removes all buffs owned by a character (e.g. on death).

## Examples

    iex> remove_owner_buffs(character)
    :ok

# `remove_tombstone`

```elixir
@spec remove_tombstone(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Removes a character's tombstone from the field (on revive or field leave).

## Examples

    iex> remove_tombstone(character)
    :ok

# `subscribe`

```elixir
@spec subscribe(Ms2ex.Schema.Character.t()) :: :ok | {:error, term()}
```

Subscribes the current process to a character's field events.

## Examples

    iex> subscribe(character)
    :ok

# `unsubscribe`

```elixir
@spec unsubscribe(Ms2ex.Schema.Character.t()) :: :ok
```

Unsubscribes the current process from a character's field events.

## Examples

    iex> unsubscribe(character)
    :ok

---

*Consult [api-reference.md](api-reference.md) for complete listing*
