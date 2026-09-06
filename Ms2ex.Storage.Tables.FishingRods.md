# `Ms2ex.Storage.Tables.FishingRods`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/fishing_rods.ex#L1)

`fishingrod.xml`: keyed by the rod code a fishing rod item carries in its
`FishingRod` function parameter.

# `entry`

```elixir
@type entry() :: %{
  item_id: integer(),
  min_mastery: integer(),
  add_mastery: integer(),
  reduce_time: integer()
}
```

# `lookup`

```elixir
@spec lookup(integer()) :: {:ok, entry()} | :error
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
