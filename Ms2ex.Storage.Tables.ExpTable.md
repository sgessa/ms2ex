# `Ms2ex.Storage.Tables.ExpTable`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/exp_table.ex#L1)

# `mob_exp`

Returns the base exp for killing a mob of the given level, or nil.

# `to_next_level`

```elixir
@spec to_next_level(pos_integer()) :: {:ok, non_neg_integer()} | :error
```

Returns `{:ok, exp_to_next_level}` for a character level, or :error.

# `typed_exp`

```elixir
@spec typed_exp(atom(), pos_integer()) :: non_neg_integer()
```

Base exp for an exp type at a level: `commonexp.xml` maps the type to one of
the `exp*.xml` tables plus a factor applied on top.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
