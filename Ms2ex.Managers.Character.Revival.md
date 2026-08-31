# `Ms2ex.Managers.Character.Revival`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character/revival.ex#L1)

Death and revival logic for a character.

All health writes funnel through `Character.Stats.set`, which calls
`check_death/1` here when health reaches 0, so every damage path is covered.

# `check_death`

```elixir
@spec check_death(Ms2ex.Schema.Character.t()) :: Ms2ex.Schema.Character.t()
```

# `instant_revive`

# `revival_meso_cost`

# `revive`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
