# `Ms2ex.Context.Mastery`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/mastery.ex#L1)

Life skills: harvesting gathering nodes and crafting mastery recipes, plus
claiming the reward boxes each mastery grade hands out.

Mastery values, gathering counts and claimed rewards live on the character
process (`Managers.Character.Mastery`); this module drives the gameplay
flows around them.

# `add`

Adds mastery through the character process so the authoritative value is
the one in memory.

# `bulk_gather`

```elixir
@spec bulk_gather(Ms2ex.Schema.Character.t(), integer(), non_neg_integer()) ::
  {:ok, Ms2ex.Schema.Character.t(), non_neg_integer()} | :error
```

Harvests a recipe `amount` times without an interact object (the Smart Push
bulk gather). Stops once the node's success rate has decayed to zero and
returns how many harvests landed.

# `claim_reward`

```elixir
@spec claim_reward(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Character.t(), map()} | {:error, atom()}
```

Claims the reward box of a mastery grade. The client addresses the box by
`mastery_type * 1000 + grade`.

# `craft`

```elixir
@spec craft(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Character.t()} | {:error, atom()}
```

Crafts a mastery recipe: consumes its ingredients and meso cost, awards the
mastery and hands out the crafted items.

# `gather`

```elixir
@spec gather(Ms2ex.Schema.Character.t(), map()) ::
  {:ok, Ms2ex.Schema.Character.t()}
  | {:error, atom(), Ms2ex.Schema.Character.t()}
```

Harvests a gathering node. Returns the updated character and whether the
harvest succeeded; failures still consume the attempt.

# `grade`

Mastery grade (level) of a type.

# `value`

Mastery value of a type.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
