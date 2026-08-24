# `Ms2ex.Crypto.SendCipher`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/ciphers/send_cipher.ex#L1)

Handles encryption of outgoing packets in the MapleStory 2 protocol.

This module manages packet encryption and header writing for data being sent
to the client.

# `t`

```elixir
@type t() :: %Ms2ex.Crypto.SendCipher{
  crypt_seq: [module() | struct()],
  iv: non_neg_integer(),
  version: non_neg_integer()
}
```

Send cipher state containing version, IV, and cryptographic sequence

# `build`

```elixir
@spec build(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
```

Creates a new send cipher with the specified parameters.

## Parameters
  * `version` - Protocol version
  * `iv` - Initialization vector as integer
  * `block_iv` - Block initialization vector

## Returns
  * New send cipher struct

# `encrypt`

```elixir
@spec encrypt(t(), binary()) :: {t(), binary()}
```

Encrypts a binary packet and adds the header.

## Parameters
  * `cipher` - Current send cipher state
  * `packet` - Raw binary packet to encrypt

## Returns
  * `{updated_cipher, encrypted_packet}` - Tuple with updated state and packet

# `write_header`

```elixir
@spec write_header(t(), binary()) :: {t(), binary()}
```

Writes the protocol header to a packet and updates the send cipher.

## Parameters
  * `send_cipher` - Current send cipher state
  * `packet` - Binary packet data

## Returns
  * `{updated_send_cipher, packet_with_header}` - Tuple with updated state and packet

---

*Consult [api-reference.md](api-reference.md) for complete listing*
