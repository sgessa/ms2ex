# `Ms2ex.TransferFlags`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/types/transfer_flag.ex#L1)

# `from_int`

Decodes an integer bitmask into its flag atoms.

## Examples

    iex> from_int(6)
    [:split, :trade]

# `has_flag?`

Whether an integer bitmask carries the given flag.

## Examples

    iex> has_flag?(6, :trade)
    true

# `to_int`

Combines a list of flag atoms into its integer bitmask.

## Examples

    iex> to_int([:trade, :split])
    6

---

*Consult [api-reference.md](api-reference.md) for complete listing*
