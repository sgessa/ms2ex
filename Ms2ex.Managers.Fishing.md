# `Ms2ex.Managers.Fishing`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/fishing.ex#L1)

The fishing manager owns a character's fishing session — the active rod,
the water tiles it reaches, the fish currently biting — and the fish
album.

The album persists on the characters row when a catch is recorded, so the
manager holds no state worth keeping between sessions: it is started when
a player begins fishing (the first rod cast) and stops when the session
ends. The manager owns only the session and the album; every flow receives
the character row as an argument, so attempts always act on the character's
current map and position. The flows run inside this process and send every
fishing packet; the behaviour logic they draw on (tile reachability, fish
selection, timers, rolls, session transitions) lives in
`Ms2ex.Context.Fishing`.

# `album`

```elixir
@spec album(integer()) :: map() | :error
```

Fish album, keyed by fish id.

# `call`

# `cast`

# `catch_fish`

```elixir
@spec catch_fish(Ms2ex.Schema.Character.t(), boolean()) :: :ok | {:error, atom()}
```

Resolves the bite: a success lands the fish and the spot's loot.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `fail_minigame`

```elixir
@spec fail_minigame(Ms2ex.Schema.Character.t()) :: :ok
```

The client lost the fight minigame; the bite stays but the game ends.

# `move_guide`

```elixir
@spec move_guide(Ms2ex.Schema.Character.t() | integer(), map(), Ms2ex.Types.Coord.t()) ::
  :ok
```

Tracks where the player dragged the bobber; nothing waits on it.

# `prepare`

```elixir
@spec prepare(Ms2ex.Schema.Character.t(), integer()) :: :ok | {:error, atom()}
```

Casts the rod: validates it, finds reachable water and spawns the bobber.

# `reel_in`

```elixir
@spec reel_in(Ms2ex.Schema.Character.t()) :: :ok
```

Reels in: removes the bobber and clears the session.

# `select_bait`

```elixir
@spec select_bait(Ms2ex.Schema.Character.t(), integer()) :: :ok | {:error, atom()}
```

Consumes a bait item and applies its timed lure effect.

# `select_bait_item`

```elixir
@spec select_bait_item(Ms2ex.Schema.Character.t(), integer()) ::
  :ok | {:error, atom()}
```

Applies a lure by item id — the client picks the lure from the item book,
not from the inventory.

# `session`

```elixir
@spec session(integer()) :: map() | nil | :error
```

The active fishing session, or nil when the player is not fishing.

# `start`

# `start`

```elixir
@spec start(Ms2ex.Schema.Character.t(), map()) :: :ok | {:error, atom()}
```

Drops the line on a tile and arms the bite timer.

# `stop`

# `use_bait_item`

```elixir
@spec use_bait_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) ::
  :ok | {:error, atom()}
```

Applies a lure by inventory item.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
