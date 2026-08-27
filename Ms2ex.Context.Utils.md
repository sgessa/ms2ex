# `Ms2ex.Context.Utils`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/utils.ex#L1)

Utility functions.

This module provides common helper functions used across the application.

# `pick_weighted`

```elixir
@spec pick_weighted([map()], atom()) :: map()
```

Picks an entry from `entries` at random, weighted by the numeric value of
the given key. Zero-weight entries never get picked; with no positive
weights a plain uniform pick is used so callers don't need to guard.

# `rand_float`

```elixir
@spec rand_float(float(), float()) :: float()
```

Generates a random float number between the given minimum and maximum values.

## Examples

    iex> rand_float(1.0, 5.0)
    3.7128453297529

    iex> rand_float(0.0, 1.0)
    0.21390374928473

---

*Consult [api-reference.md](api-reference.md) for complete listing*
