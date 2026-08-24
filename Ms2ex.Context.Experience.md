# `Ms2ex.Context.Experience`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/experience.ex#L1)

Context module for character experience-related operations.

This module provides functions for managing character experience points,
including level-ups and experience calculations.

# `maybe_add_exp`

```elixir
@spec maybe_add_exp(Ms2ex.Schema.Character.t(), non_neg_integer()) ::
  {:ok, Ms2ex.Schema.Character.t()} | {:error, Ecto.Changeset.t()}
```

Adds experience to a character and handles level-ups if necessary.

If the character reaches the maximum level, no further experience is added.

If the character gains enough experience to level up,
the remaining experience is added to the new level.

## Parameters

  * `character` - The character receiving experience
  * `exp_gained` - Amount of experience to add

## Examples

    iex> maybe_add_exp(character, 100)
    {:ok, %Schema.Character{exp: 250}}

    iex> maybe_add_exp(level_99_character, 10000)
    {:ok, %Schema.Character{level: 100, exp: 0}}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
