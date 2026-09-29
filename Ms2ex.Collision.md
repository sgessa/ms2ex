# `Ms2ex.Collision`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/collision.ex#L1)

Attack hit volumes. A skill attack's range doc describes a prism: a
polygon footprint (box, cylinder, frustum or hole-cylinder) projected
from an anchor position along a facing angle and raised over a height
band. A position is inside the prism when its footprint point falls
within the polygon and its height within the band.

Ranges typed `none` carry no volume at all — no prism exists for them
and nothing is ever inside.

# `polygon`

```elixir
@type polygon() ::
  {:trapezoid, [{number(), number()}]}
  | {:circle, {number(), number(), number()}}
  | {:hole_circle, {number(), number(), number(), number()}}
  | :none
```

# `prism`

```elixir
@type prism() :: %{polygon: polygon(), base_z: number(), top_z: number()}
```

# `build_prism`

```elixir
@spec build_prism(map(), Ms2ex.Types.Coord.t(), number()) :: prism()
```

Builds the hit-volume prism for a range doc anchored at `position`,
facing `angle` (degrees, the caster's yaw). The facing rotates the
footprint and the range's own rotate offset rides on top.

# `contains?`

```elixir
@spec contains?(prism(), %{x: number(), y: number(), z: number()}) :: boolean()
```

Whether a position falls inside the prism.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
