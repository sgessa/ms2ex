# `Ms2ex.Storage.Triggers`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/triggers.ex#L1)

Per-map trigger scripts, keyed by the map's xblock name. Each document
holds every script of the xblock: states with on-enter/on-exit actions
plus ordered conditions carrying their transition target.

# `get_scripts`

```elixir
@spec get_scripts(String.t() | nil) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
