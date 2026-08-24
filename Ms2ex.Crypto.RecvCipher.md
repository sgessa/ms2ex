# `Ms2ex.Crypto.RecvCipher`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/ciphers/recv_cipher.ex#L1)

Handles decryption of incoming packets in the MapleStory 2 encryption protocol.

This module manages packet header parsing and decryption for data received
from the client.

# `t`

```elixir
@type t() :: %Ms2ex.Crypto.RecvCipher{
  crypt_seq: [module() | struct()],
  iv: non_neg_integer(),
  version: non_neg_integer()
}
```

Receive cipher state containing version, IV, and cryptographic sequence

# `build`

```elixir
@spec build(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
```

Creates a new receive cipher with the specified parameters.

## Parameters
  * `version` - Protocol version
  * `iv` - Initialization vector as integer
  * `block_iv` - Block initialization vector

## Returns
  * New receive cipher struct

# `decrypt`

```elixir
@spec decrypt(t(), binary()) :: {t(), binary()}
```

Decrypts a binary packet by first parsing the header and then applying the decryption sequence.

## Parameters
  * `cipher` - Current receive cipher state
  * `data` - Binary packet data to decrypt

## Returns
  * `{updated_cipher, decrypted_packet}` - Tuple with updated state and packet

---

*Consult [api-reference.md](api-reference.md) for complete listing*
