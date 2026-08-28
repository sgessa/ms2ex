# `Ms2ex.Context.Damage`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/damage.ex#L1)

Context module for damage calculation operations.

This module provides functions for calculating damage dealt between entities,
including critical hit calculation, skill damage, and fall damage.

# `calculate`

```elixir
@spec calculate(Ms2ex.Types.SkillCast.t(), Ms2ex.Types.FieldNpc.t(), boolean()) :: %{
  dmg: integer(),
  crit?: boolean()
}
```

Calculates the damage dealt by a skill cast on a field NPC.

The attack roll is the character's weapon attack plus bonus attack; an
unarmed character falls back to the job attack stat. Skill rate scales the
hit, target defense and resistance reduce it, and piercing ignores a share
of both. Critical hits multiply by the critical damage stat.

## Parameters

  * `skill_cast` - The skill being cast
  * `mob` - The target field NPC
  * `crit?` - Whether the hit is a critical hit (default: false)

## Examples

    iex> calculate(skill_cast, mob)
    %{dmg: 1, crit?: false}

# `calculate_fall_dmg`

```elixir
@spec calculate_fall_dmg(Ms2ex.Schema.Character.t(), number()) :: integer()
```

Calculates damage a character takes from falling.

## Examples

    iex> calculate_fall_dmg(character, 0)
    24

# `calculate_rate`

Calculates damage for a given rate (e.g. a damage-over-time tick) instead of
the skill's own rate.

# `roll_crit`

```elixir
@spec roll_crit(Ms2ex.Schema.Character.t()) :: boolean()
```

Determines if a character's attack results in a critical hit based on their critical rate.

The critical rate is clamped between 0 and 400, and the roll is against 1000.

## Examples

    iex> roll_crit(character)
    true

    iex> roll_crit(character)
    false

---

*Consult [api-reference.md](api-reference.md) for complete listing*
