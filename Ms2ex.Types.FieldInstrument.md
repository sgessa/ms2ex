# `Ms2ex.Types.FieldInstrument`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/types/field_instrument.ex#L1)

# `t`

```elixir
@type t() :: %Ms2ex.Types.FieldInstrument{
  ensemble?: term(),
  improvising?: term(),
  metadata: term(),
  object_id: term(),
  owner_character_id: term(),
  owner_id: term(),
  position: term(),
  score: term(),
  start_tick: term()
}
```

# `from_item`

```elixir
@spec from_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t(), keyword()) ::
  {:ok, t()} | :error
```

Resolves the instrument an item opens. Instrument items carry their
instrument table id in the `OpenInstrument` item function parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
