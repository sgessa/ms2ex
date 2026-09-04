# `Ms2ex.Context.Insignias`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/insignias.ex#L1)

Name tag symbols. Each insignia is gated on a condition the wearer has to
keep meeting, so the symbol is only drawn while the condition holds.

# `display?`

```elixir
@spec display?(Ms2ex.Schema.Character.t()) :: boolean()
```

Whether the character's current insignia should be drawn above their head.

# `display?`

```elixir
@spec display?(Ms2ex.Schema.Character.t(), map()) :: boolean()
```

Whether the character meets an insignia's condition.

# `equip`

```elixir
@spec equip(Ms2ex.Schema.Character.t(), integer(), keyword()) ::
  {:ok, Ms2ex.Schema.Character.t(), boolean()} | :error
```

Wears an insignia: persists it, swaps the buff the previous one granted for
the new one and reports whether the symbol should be drawn.

`force: true` displays and grants the insignia regardless of its condition,
for the admin command.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
