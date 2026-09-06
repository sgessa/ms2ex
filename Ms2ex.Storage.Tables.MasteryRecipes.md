# `Ms2ex.Storage.Tables.MasteryRecipes`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/mastery_recipes.ex#L1)

`masteryreceipe.xml`: one entry per gathering node and craft recipe, keyed
by recipe id (the id an interact object's `item.recipe_id` points at).

# `entry`

```elixir
@type entry() :: %{
  id: integer(),
  type: atom(),
  no_reward_exp: boolean(),
  required_mastery: integer(),
  required_meso: integer(),
  required_quests: [integer()],
  reward_exp: integer(),
  reward_mastery: integer(),
  high_rate_limit_count: integer(),
  normal_rate_limit_count: integer(),
  required_items: [item_component()],
  habitat_map_ids: [integer()],
  reward_items: [item_component()]
}
```

# `item_component`

```elixir
@type item_component() :: %{
  item_id: integer(),
  rarity: integer(),
  amount: integer(),
  tag: atom()
}
```

# `lookup`

```elixir
@spec lookup(integer()) :: {:ok, entry()} | :error
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
