# `Ms2ex.Storage.Tables.ShopItems`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/shop_items.ex#L1)

Vendor shop stock entries, grouped by shop id and keyed by the shop item
id (`sn`) each entry carries in the shop window packets.

# `get`

```elixir
@spec get(integer(), integer()) :: map() | nil
```

# `list`

```elixir
@spec list(integer()) :: %{required(integer()) =&gt; map()}
```

Stock entries of a shop keyed by shop item id, or an empty map.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
