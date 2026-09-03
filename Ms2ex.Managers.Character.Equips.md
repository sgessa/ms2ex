# `Ms2ex.Managers.Character.Equips`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character/equips.ex#L1)

Equip transitions owned by the character process.

Equipping moves items between inventory and equipment, rebuilds the
character's derived stats, and must keep the character's cached equip list
coherent: other players' field serialization reads that list through the
character manager. A transition therefore runs as one step inside the
manager — the request is validated, conflicting items are unequipped into
the freed space, the incoming item is equipped, the equip list and stats
are refreshed once, and the field plus the owner's client are notified of
the result.

# `equip`

```elixir
@spec equip(Ms2ex.Schema.Character.t(), integer(), String.t()) ::
  {:ok, Ms2ex.Schema.Character.t()} | :error
```

# `unequip`

```elixir
@spec unequip(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Character.t()} | :error
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
