# `Ms2ex.Crypto.XorCrypter`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/crypters/xor_crypter.ex#L1)

Implements a XOR-based crypter.

This crypter applies XOR operations with values derived from the protocol version
to encrypt and decrypt data.

# `t`

```elixir
@type t() :: %Ms2ex.Crypto.XorCrypter{table: [float()]}
```

XOR crypter state containing a table of values

# `build`

```elixir
@spec build(non_neg_integer()) :: t()
```

Builds a XOR crypter with values derived from the protocol version.

## Parameters
  * `version` - Protocol version

## Returns
  * XOR crypter struct

# `decrypt`

```elixir
@spec decrypt(t(), [non_neg_integer()]) :: [non_neg_integer()]
```

Decrypts data using XOR operations.

## Parameters
  * `xc` - XOR crypter struct
  * `data` - List of bytes to decrypt

## Returns
  * Decrypted list of bytes

# `encrypt`

```elixir
@spec encrypt(t(), [non_neg_integer()]) :: [non_neg_integer()]
```

Encrypts data using XOR operations.

## Parameters
  * `xc` - XOR crypter struct
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
