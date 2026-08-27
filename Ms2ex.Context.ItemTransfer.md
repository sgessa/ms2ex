# `Ms2ex.Context.ItemTransfer`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/item_transfer.ex#L1)

Item trade-state semantics: transfer flags and character binding.

Contexts only deal with atoms: transfer types are `Enums.TransferType`
keys (`:tradeable`, `:bind_on_loot`, ...) and transfer flags are lists of
flag atoms (`[:trade, :split]`, `[:bind, :limit_trade]`, ...). The
integer bitmask is a storage/packet concern handled by
`Ms2ex.TransferFlags` and `Ms2ex.EctoTypes.TransferFlags`.

Flags are derived from item metadata (transfer type, trade count, rarity
vs trade-max rarity), mirroring the reference `GetTransferFlag` logic.
Binding marks an item bound (zeroing remaining trades) when its transfer
type requires it.

# `apply`

```elixir
@spec apply(Ms2ex.Schema.Item.t()) :: Ms2ex.Schema.Item.t()
```

Sets the trade state from item metadata. Items with a tradeable transfer
type, enough rarity headroom and a non-zero trade count stay tradeable;
bind-on-loot/equip/use items start bind-flagged. Explicitly provided
flags (e.g. from commands) are preserved.

# `flags`

```elixir
@spec flags(atom(), boolean(), boolean()) :: [atom()]
```

Computes the transfer flags for a transfer type given whether the item
has zero remaining trades and whether its rarity sits below the
trade-max rarity.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
