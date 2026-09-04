# `Ms2ex.Storage.Tables.Instruments`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/instruments.ex#L1)

# `metadata`

```elixir
@type metadata() :: %{
  id: integer(),
  equip_id: integer(),
  score_count: integer(),
  category: integer(),
  midi_id: integer(),
  percussion_id: integer()
}
```

# `lookup`

```elixir
@spec lookup(pos_integer()) :: {:ok, metadata()} | :error
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
