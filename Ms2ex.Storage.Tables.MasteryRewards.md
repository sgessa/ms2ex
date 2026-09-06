# `Ms2ex.Storage.Tables.MasteryRewards`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/mastery_rewards.ex#L1)

`mastery.xml`: per mastery type, the mastery value each grade starts at and
the reward box handed out for reaching it.

# `entry`

```elixir
@type entry() :: %{
  value: integer(),
  item_id: integer(),
  item_rarity: integer(),
  item_amount: integer()
}
```

# `grade`

```elixir
@spec grade(atom(), integer()) :: integer()
```

The grade a mastery value has reached: the highest grade whose starting
value the mastery covers, never below 1.

# `grades`

```elixir
@spec grades(atom()) :: %{required(integer()) =&gt; entry()}
```

# `lookup`

```elixir
@spec lookup(atom(), integer()) :: {:ok, entry()} | :error
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
