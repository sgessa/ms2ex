# `Ms2ex.Formulas.Shop`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/formulas/shop.ex#L1)

Vendor shop pricing: what an npc pays for a sold item and how instant
restock prices escalate with repeated restocks.

# `excess_restock_cost`

```elixir
@spec excess_restock_cost(atom(), integer()) :: {atom(), integer()}
```

# `next_reset_day`

The next date strictly after `date` that is the weekly reset day.

# `sell_price`

```elixir
@spec sell_price(map(), integer(), integer()) :: integer()
```

The meso value an npc shop pays for an item of the given metadata and
rarity. Gear sells at a third of its price; the client's fixed prices
replace the table for level 57+ gear.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
