//! Native packet crypto for the MapleStory 2 wire protocol: builds the
//! crypter sequence selected by the protocol version and block IV, and
//! applies it to packet payloads in a single pass.
//!
//! A crypter is handed to Elixir as an opaque term (`:rearrange`,
//! `{:xor, byte, byte}` or `{:table, encrypted, decrypted}`) so a session
//! keeps an immutable sequence around and pays one NIF call per packet.

use rustler::{Atom, Binary, Decoder, Encoder, Env, Error, NifResult, OwnedBinary, Term};

mod atoms {
    rustler::atoms! {
        rearrange,
        xor,
        table,
    }
}

const REARRANGE_INDEX: u32 = 1;
const XOR_INDEX: u32 = 2;
const TABLE_INDEX: u32 = 3;
const TABLE_SIZE: usize = 256;

// -- congruential random generator -------------------------------------------
//
// Three cross-perturbed LCG streams; the wire format's tables and IV
// advancement are all derived from it, so every branch must reproduce the
// exact 32-bit arithmetic (wrapping multiplies, logical shifts).

struct Rand32 {
    s1: u32,
    s2: u32,
    s3: u32,
}

impl Rand32 {
    fn new(seed: u32) -> Self {
        let rand = Self::crt_rand(seed);

        Rand32 {
            s1: seed | 0x0010_0000,
            s2: rand | 0x0000_1000,
            s3: Self::crt_rand(rand) | 0x0000_0010,
        }
    }

    fn crt_rand(seed: u32) -> u32 {
        seed.wrapping_mul(214_013).wrapping_add(2_531_011)
    }

    fn random(&mut self) -> u32 {
        self.s1 = ((self.s1 << 12) & 0xFFFF_E000) ^ ((self.s1 >> 6) & 0x0000_1FFF) ^ (self.s1 >> 19);
        self.s2 = ((self.s2 << 4) & 0xFFFF_FF80) ^ ((self.s2 >> 23) & 0x0000_007F) ^ (self.s2 >> 25);
        self.s3 =
            ((self.s3 << 17) & 0xFFE0_0000) ^ ((self.s3 >> 8) & 0x001F_FFFF) ^ (self.s3 >> 11);

        self.s1 ^ self.s2 ^ self.s3
    }

    fn random_float(&mut self) -> f32 {
        // mantissa bits grafted onto 1.0, then the implicit leading one is
        // stripped by the subtraction — uniform in [0, 1)
        f32::from_bits((self.random() & 0x007F_FFFF) | 0x3F80_0000) - 1.0
    }
}

// -- crypters ----------------------------------------------------------------

#[derive(Clone)]
enum Crypter {
    // swaps each byte of the first half with its mirror in the second half
    Rearrange,
    // alternating XOR with two version-derived bytes
    Xor([u8; 2]),
    // byte substitution through a version-shuffled permutation and its inverse
    Table {
        encrypted: Box<[u8; TABLE_SIZE]>,
        decrypted: Box<[u8; TABLE_SIZE]>,
    },
}

impl Crypter {
    fn apply(&self, data: &mut [u8], encrypt: bool) {
        match self {
            Crypter::Rearrange => {
                let len = data.len() >> 1;
                for i in 0..len {
                    data.swap(i, i + len);
                }
            }
            Crypter::Xor(table) => {
                for (i, byte) in data.iter_mut().enumerate() {
                    *byte ^= table[i & 1];
                }
            }
            Crypter::Table { encrypted, decrypted } => {
                let table = if encrypt { encrypted.as_ref() } else { decrypted.as_ref() };
                for byte in data.iter_mut() {
                    *byte = table[*byte as usize];
                }
            }
        }
    }
}

impl Encoder for Crypter {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            Crypter::Rearrange => atoms::rearrange().to_term(env),
            Crypter::Xor(table) => (atoms::xor(), table[0], table[1]).encode(env),
            Crypter::Table {
                encrypted,
                decrypted,
            } => {
                let encrypted = binary_term(env, encrypted.as_ref());
                let decrypted = binary_term(env, decrypted.as_ref());
                (atoms::table(), encrypted, decrypted).encode(env)
            }
        }
    }
}

impl<'a> Decoder<'a> for Crypter {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        if term.is_atom() {
            let atom: Atom = term.decode()?;
            if atom == atoms::rearrange() {
                return Ok(Crypter::Rearrange);
            }
            return Err(Error::RaiseTerm(Box::new("unknown crypter tag")));
        }

        let (tag, first, second): (Atom, Term, Term) = term
            .decode()
            .map_err(|_| Error::RaiseTerm(Box::new("malformed crypter")))?;

        if tag == atoms::xor() {
            let table: [u8; 2] = [first.decode()?, second.decode()?];
            return Ok(Crypter::Xor(table));
        }

        if tag == atoms::table() {
            let encrypted: Binary = first.decode()?;
            let decrypted: Binary = second.decode()?;
            if encrypted.len() != TABLE_SIZE || decrypted.len() != TABLE_SIZE {
                return Err(Error::RaiseTerm(Box::new(
                    "crypter tables must hold 256 bytes",
                )));
            }
            let mut encrypted_buf = [0u8; TABLE_SIZE];
            let mut decrypted_buf = [0u8; TABLE_SIZE];
            encrypted_buf.copy_from_slice(encrypted.as_slice());
            decrypted_buf.copy_from_slice(decrypted.as_slice());
            return Ok(Crypter::Table {
                encrypted: Box::new(encrypted_buf),
                decrypted: Box::new(decrypted_buf),
            });
        }

        Err(Error::RaiseTerm(Box::new("unknown crypter tag")))
    }
}

fn binary_term<'a>(env: Env<'a>, bytes: &[u8]) -> Term<'a> {
    let mut owned = OwnedBinary::new(bytes.len()).expect("binary allocation failed");
    owned.as_mut_slice().copy_from_slice(bytes);
    owned.release(env).to_term(env)
}

// -- sequence construction ----------------------------------------------------
//
// Each crypter claims a slot `(version + index) % 3 + 1`; the digits of the
// block IV then read that array out, least significant digit first. The same
// crypter is applied once per occurrence of its digit.

fn build_crypt_seq(version: u32, block_iv: u32) -> Vec<Crypter> {
    let mut crypts: [Option<Crypter>; 4] = [None, None, None, None];
    crypts[crypter_index(version, REARRANGE_INDEX)] = Some(Crypter::Rearrange);
    crypts[crypter_index(version, XOR_INDEX)] = Some(xor_crypter(version));
    crypts[crypter_index(version, TABLE_INDEX)] = Some(table_crypter(version));

    let mut seq = Vec::new();
    let mut block = block_iv;
    while block > 0 {
        if let Some(crypter) = &crypts[(block % 10) as usize] {
            seq.push(crypter.clone());
        }
        block /= 10;
    }
    seq
}

fn crypter_index(version: u32, index: u32) -> usize {
    version.wrapping_add(index).wrapping_rem(3).wrapping_add(1) as usize
}

fn xor_crypter(version: u32) -> Crypter {
    let mut rand1 = Rand32::new(version);
    let mut rand2 = Rand32::new(version.wrapping_mul(2));

    Crypter::Xor([
        (rand1.random_float() * 255.0) as u8,
        (rand2.random_float() * 255.0) as u8,
    ])
}

fn table_crypter(version: u32) -> Crypter {
    let mut encrypted = [0u8; TABLE_SIZE];
    for (i, byte) in encrypted.iter_mut().enumerate() {
        *byte = i as u8;
    }
    shuffle(&mut encrypted, version);

    let mut decrypted = [0u8; TABLE_SIZE];
    for (i, &byte) in encrypted.iter().enumerate() {
        decrypted[byte as usize] = i as u8;
    }

    Crypter::Table {
        encrypted: Box::new(encrypted),
        decrypted: Box::new(decrypted),
    }
}

// Fisher-Yates walked from the last slot down, seeded with the squared version
fn shuffle(data: &mut [u8; TABLE_SIZE], version: u32) {
    let mut rand32 = Rand32::new((version as f64).powi(2) as u32);

    for i in (1..TABLE_SIZE).rev() {
        let rand = (rand32.random() % (i as u32 + 1)) as usize;
        data.swap(i, rand);
    }
}

// -- nifs ---------------------------------------------------------------------

/// The crypter sequence a session applies to every packet: one crypter per
/// digit of the block IV, resolved against the protocol version.
#[rustler::nif]
fn crypt_seq(version: u32, block_iv: u32) -> Vec<Crypter> {
    build_crypt_seq(version, block_iv)
}

/// Applies the sequence to a payload in order. Symmetric crypters ignore the
/// direction; the substitution table picks its forward or inverse half.
#[rustler::nif]
fn transform<'a>(
    env: Env<'a>,
    crypt_seq: Vec<Crypter>,
    data: Binary<'a>,
    encrypt: bool,
) -> Result<Binary<'a>, Error> {
    let mut owned = OwnedBinary::new(data.len())
        .ok_or_else(|| Error::RaiseTerm(Box::new("packet buffer allocation failed")))?;
    owned.as_mut_slice().copy_from_slice(&data);

    for crypter in &crypt_seq {
        crypter.apply(owned.as_mut_slice(), encrypt);
    }

    Ok(owned.release(env))
}

/// The congruential step that advances a packet IV between frames.
#[rustler::nif]
fn crt_rand(seed: u32) -> u32 {
    Rand32::crt_rand(seed)
}

rustler::init!("Elixir.Ms2ex.Crypto.Native");
