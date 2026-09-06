# `Ms2ex.Context.Fishing`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/fishing.ex#L1)

Fishing, ported from the reference FishingManager.

Preparing a rod finds the water tiles in front of the player, spawns the
bobber guide object and hands the tiles to the client. Casting picks a fish
from the map's fish boxes and arms a bite timer; catching rolls the size,
updates the album and awards fishing mastery.

# `catch_fish`

```elixir
@spec catch_fish(Ms2ex.Schema.Character.t(), boolean()) :: :ok | {:error, atom()}
```

Resolves the bite: a success lands the fish and the spot's loot.

# `fail_minigame`

The client lost the fight minigame; the bite stays but the game ends.

# `prepare`

```elixir
@spec prepare(Ms2ex.Schema.Character.t(), integer()) :: :ok | {:error, atom()}
```

Casts the rod: validates it, finds reachable water and spawns the bobber.

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

# `start`

```elixir
@spec start(Ms2ex.Schema.Character.t(), map()) :: :ok | {:error, atom()}
```

Drops the line on a tile and arms the bite timer.

# `stop`

```elixir
@spec stop(Ms2ex.Schema.Character.t()) :: :ok
```

Reels in: removes the bobber and clears the session.

# `use_bait_item`

```elixir
@spec use_bait_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) ::
  :ok | {:error, atom()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
