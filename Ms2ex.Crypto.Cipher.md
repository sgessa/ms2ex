# `Ms2ex.Crypto.Cipher`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/ciphers/cipher.ex#L1)

Core module handling the MapleStory 2 encryption protocol, providing methods for building
cryptographic sequences and managing initialization vectors (IVs).

This module coordinates the different crypters (Rearrange, Table, and XOR) and provides
utility functions for cipher operations.

# `crypt_seq`

```elixir
@type crypt_seq() :: [module() | struct()]
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
  * A list of crypter modules/structs in the proper sequence

# `iv_to_int`

```elixir
@spec iv_to_int(binary()) :: non_neg_integer()
```

Converts a binary IV to its integer representation.

## Parameters
  * `iv` - Binary initialization vector (4 bytes)

## Returns
  * Integer representation of the IV

# `mask`

```elixir
@spec mask(integer(), 32 | 64) :: non_neg_integer()
```

Applies a bit mask to an integer of specified bit width.

## Parameters
  * `n` - Integer to mask
  * `bits` - Bit width (default: 32)

## Returns
  * Masked integer value

---

*Consult [api-reference.md](api-reference.md) for complete listing*
