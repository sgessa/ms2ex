# `Ms2ex.Crypto.Cipher`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/ciphers/cipher.ex#L1)

Core module handling the MapleStory 2 encryption protocol, providing methods for building
cryptographic sequences and managing initialization vectors (IVs).

The crypter sequence and payload transforms run in the native crypto library
(`Ms2ex.Crypto.Native`); this module keeps the IV handling and header sizing.

# `crypt_seq`

```elixir
@type crypt_seq() :: Ms2ex.Crypto.Native.crypt_seq()
```

A cryptographic sequence used in the encryption process

# `advance_iv`

```elixir
@spec advance_iv(struct()) :: struct()
```

Updates the IV in a cipher using the congruential random algorithm.

## Parameters
  * `cipher` - Cipher struct containing an IV

## Returns
  * Updated cipher with new IV

# `generate_iv`

```elixir
@spec generate_iv() :: binary()
```

Generates a cryptographically secure random IV (4 bytes).

## Returns
  * Binary initialization vector

# `header_size`

```elixir
@spec header_size() :: non_neg_integer()
```

Returns the header size used in the protocol.

## Returns
  * Header size in bytes

# `init_crypt_seq`

```elixir
@spec init_crypt_seq(non_neg_integer(), non_neg_integer()) :: crypt_seq()
```

Initializes a cryptographic sequence based on version and block IV.

## Parameters
  * `version` - Protocol version number
  * `block_iv` - Block initialization vector

## Returns
  * A crypter sequence in the order defined by the block IV digits

# `iv_to_int`

```elixir
@spec iv_to_int(binary()) :: non_neg_integer()
```

Converts a binary IV to its integer representation.

## Parameters
  * `iv` - Binary initialization vector (4 bytes)

## Returns
  * Unsigned integer representation of the IV

---

*Consult [api-reference.md](api-reference.md) for complete listing*
