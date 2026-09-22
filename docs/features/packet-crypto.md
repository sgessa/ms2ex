# Packet crypto

Status: the wire encryption runs on the native runtime. `lib/ms2ex/crypto/`
holds the IV handling and header framing; the crypter sequence and the
per-packet payload transforms live in the Rust NIF (`native/crypto`, built by
`mix compile` via Rustler).

## How a session is keyed

Three inputs select the encryption: the protocol `version` (config, currently
12), a random 4-byte IV per direction (`Cipher.generate_iv/0`, sent to the
client in the handshake packet), and the block IV (defaults to the version).
IVs are 32-bit unsigned integers everywhere after `Cipher.iv_to_int/1`.

## Crypter sequence

Each crypter claims a slot `(version + index) % 3 + 1`:

- index 1 — **rearrange**: swaps each byte of the first payload half with its
  mirror in the second half (self-inverse)
- index 2 — **xor**: XORs the payload with two version-derived bytes,
  alternating per byte parity (self-inverse); the bytes come from
  `rand32.random_float() * 255` for seeds `version` and `2 * version`
- index 3 — **table**: byte substitution through a 256-entry permutation and
  its inverse; the permutation is a Fisher-Yates walk seeded with a
  congruential generator seeded with `version²`

`Native.crypt_seq(version, block_iv)` reads that slot array with the digits of
the block IV, least significant digit first — the sequence is one crypter per
digit, and a repeated digit repeats the crypter. Send applies the sequence in
order; recv applies the reversed sequence, so the two undo each other.

## Per-packet framing

Every frame is `enc_seq :: u16` + `payload_size :: i32` + payload
(`Cipher.header_size/0` = 6). `enc_seq` is `version XOR (iv >>> 16)` on send
and the same XOR on recv as a check (mismatches are logged, not dropped).
After each frame the direction's IV advances through the congruential step
`Native.crt_rand/1` (`iv * 214013 + 2531011`, mod 2³²).

- `SendCipher.encrypt/2` transforms the payload natively, then prepends the
  header (`write_header/2` is also used for the handshake packet, which is
  sent unencrypted)
- `RecvCipher.decrypt/2` parses the header, advances the IV, then transforms
  the payload natively with the reversed sequence

## Native surface

`Ms2ex.Crypto.Native` exposes exactly three NIFs: `crypt_seq/2` (build once
per session), `transform/3` (one call per packet — applies every crypter in
the sequence over the payload in a single copy), and `crt_rand/1`. Crypters
cross the boundary as opaque terms (`:rearrange`, `{:xor, byte, byte}`,
`{:table, binary, binary}`) so sessions keep an immutable sequence and no
native resources are shared between processes.

## Verification

`test/ms2ex/crypto_test.exs` pins the native implementation against
`test/fixtures/crypto/reference_vectors.json`: congruential outputs,
substitution and xor tables, and whole frames (header + payload) for several
version/IV/block-IV combinations, including a high-bit IV. Round-trip and
involution properties cover the rest.

## Known gaps

- the recv path logs invalid sequence headers but still attempts decryption;
  a genuine mismatch yields garbage rather than a disconnect
- the full generator sequence behind the tables is internal to the NIF — only
  its derived artifacts (tables, xor bytes, IV step) are reachable
