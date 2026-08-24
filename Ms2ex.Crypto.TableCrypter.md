# `Ms2ex.Crypto.TableCrypter`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/crypters/table_crypter.ex#L1)

Implements a table-based substitution crypter.

This crypter uses a shuffled table based on the protocol version to perform
substitution encryption and decryption.

# `t`

```elixir
@type t() :: %Ms2ex.Crypto.TableCrypter{
  decrypted: [non_neg_integer()],
  encrypted: [non_neg_integer()]
}
```

Table crypter state containing encryption and decryption tables

# `build`

```elixir
@spec build(non_neg_integer()) :: t()
```

Builds a table crypter with encryption and decryption tables based on version.

## Parameters
  * `version` - Protocol version

## Returns
  * Table crypter struct

# `decrypt`

```elixir
@spec decrypt(t(), [non_neg_integer()]) :: [non_neg_integer()]
```

Decrypts data using the decryption table.

## Parameters
  * `tc` - Table crypter struct
  * `data` - List of bytes to decrypt

## Returns
  * Decrypted list of bytes

# `encrypt`

```elixir
@spec encrypt(t(), [non_neg_integer()]) :: [non_neg_integer()]
```

Encrypts data using the encryption table.

## Parameters
  * `tc` - Table crypter struct
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
