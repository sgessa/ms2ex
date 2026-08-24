# `Ms2ex.Crypto.RearrangeCrypter`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/crypters/rearrange_crypter.ex#L1)

Implements a crypter that rearranges bytes in a packet.

This crypter swaps bytes between the first and second halves of the packet data.
The operation is symmetric, so encryption and decryption use the same algorithm.

# `build`

```elixir
@spec build() :: String.t()
```

Returns an empty string as the crypter requires no state.

## Returns
  * Empty string

# `decrypt`

```elixir
@spec decrypt([non_neg_integer()]) :: [non_neg_integer()]
```

Decrypts data by rearranging bytes.

## Parameters
  * `data` - List of bytes to decrypt

## Returns
  * Decrypted list of bytes

# `encrypt`

```elixir
@spec encrypt([non_neg_integer()]) :: [non_neg_integer()]
```

Encrypts data by rearranging bytes.

## Parameters
  * `data` - List of bytes to encrypt

## Returns
  * Encrypted list of bytes

# `index`

```elixir
@spec index() :: non_neg_integer()
```

Returns the base index for this crypter.

## Returns
  * Index value

---

*Consult [api-reference.md](api-reference.md) for complete listing*
