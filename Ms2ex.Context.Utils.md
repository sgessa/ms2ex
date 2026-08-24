# `Ms2ex.Context.Utils`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/utils.ex#L1)

Utility functions.

This module provides common helper functions used across the application.

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
