# `Ms2ex.Crypto.Rand32`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/crypto/rand32.ex#L1)

Implements a 32-bit random number generator used in the MapleStory 2 encryption protocol.

This module provides functionality to create and manipulate random number states based on seeds,
as well as generate random integers and floats from those states.

# `rand32`

```elixir
@type rand32() :: {:rand32, non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

Random number generator state

# `seed`

```elixir
@type seed() :: non_neg_integer()
```

# `build`

```elixir
@spec build(seed()) :: rand32()
```

Builds a new rand32 state from a given seed.

## Parameters
  * `seed` - An integer seed value to initialize the generator

## Returns
  * A tuple representing the random number generator state

# `crt_rand`

```elixir
@spec crt_rand(seed()) :: non_neg_integer()
```

Creates a new random integer based on the provided seed using congruential algorithm.

## Parameters
  * `seed` - An integer seed value to generate the random number

## Returns
  * A new random integer

# `random`

```elixir
@spec random(rand32()) :: {rand32(), non_neg_integer()}
```

Generates a new random integer and returns the updated random state.

## Parameters
  * `rand32` - The current random number generator state

## Returns
  * `{new_rand32, random_value}` - Tuple containing the updated state and random integer

# `random_float`

```elixir
@spec random_float(rand32()) :: {rand32(), float()}
```

Generates a random floating-point number between 0 and 1.

## Parameters
  * `rand32` - The current random number generator state

## Returns
  * `{new_rand32, random_value}` - Tuple containing the updated state and random float

---

*Consult [api-reference.md](api-reference.md) for complete listing*
