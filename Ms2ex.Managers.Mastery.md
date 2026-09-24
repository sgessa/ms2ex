# `Ms2ex.Managers.Mastery`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/mastery.ex#L1)

# `add`

```elixir
@spec add(integer(), atom(), integer(), keyword()) :: :ok | :error
```

Adds mastery. The value never decreases and is capped at the type's
maximum; the client is told the new value and grade changes feed the
matching trophy/quest conditions.

# `bulk_gather`

```elixir
@spec bulk_gather(Ms2ex.Schema.Character.t(), integer(), non_neg_integer()) ::
  {:ok, Ms2ex.Schema.Character.t(), non_neg_integer()} | :error
```

Harvests a recipe `amount` times without an interact object (the Smart Push
bulk gather). Stops once the node's success rate has decayed to zero and
returns how many harvests landed.

# `bump_gathering_count`

```elixir
@spec bump_gathering_count(integer(), integer()) :: :ok | :error
```

Bumps the harvest counter of a gathering recipe and persists it.

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `claim_reward_box`

```elixir
@spec claim_reward_box(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Character.t(), map()} | {:error, atom()}
```

Claims the reward box of a mastery grade. The client addresses the box by
`mastery_type * 1000 + grade`. Runs in the caller's process.

# `craft`

```elixir
@spec craft(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Character.t()} | {:error, atom()}
```

Crafts a mastery recipe: consumes its ingredients and meso cost, awards
the mastery and hands out the crafted items. Runs in the caller's process.

# `gather`

```elixir
@spec gather(Ms2ex.Schema.Character.t(), map()) ::
  {:ok, Ms2ex.Schema.Character.t()}
  | {:error, atom(), Ms2ex.Schema.Character.t()}
```

Harvests a gathering node. Returns the updated character and whether the
harvest succeeded; failures still consume the attempt.

# `gathering_counts`

```elixir
@spec gathering_counts(integer()) :: map() | :error
```

Returns the character's harvest counters, keyed by recipe id.

# `grade`

```elixir
@spec grade(integer(), atom()) :: non_neg_integer() | :error
```

Mastery grade (level) a type has reached.

# `reset_gathering_counts`

```elixir
@spec reset_gathering_counts(integer()) :: :ok
```

Drops the cached harvest counters after the daily reset cleared them.

# `rewards_claimed`

```elixir
@spec rewards_claimed(integer()) :: map() | :error
```

Claimed mastery grade reward boxes, keyed by reward box id.

# `start`

# `stop`

# `value`

```elixir
@spec value(integer(), atom()) :: non_neg_integer() | :error
```

Mastery value of a type.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
