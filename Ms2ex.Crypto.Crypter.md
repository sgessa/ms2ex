# `Ms2ex.Crypto.Crypter`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/crypters/crypter.ex#L1)

Base module for crypter implementations providing common functionality.

This module defines utilities used by the concrete crypter implementations.

# `get_index`

```elixir
@spec get_index(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
```

Calculates the index for a crypter based on the protocol version.

## Parameters
  * `version` - Protocol version
  * `index` - Base index value for the crypter

## Returns
  * Calculated index for the crypter in the sequence

---

*Consult [api-reference.md](api-reference.md) for complete listing*
