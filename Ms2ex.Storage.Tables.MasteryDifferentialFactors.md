# `Ms2ex.Storage.Tables.MasteryDifferentialFactors`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/mastery_differential_factors.ex#L1)

`masterydifferentialfactor.xml`: how much mastery a harvest still awards
when the recipe sits below the player's grade. Only the number of entries
with a positive factor is used: once the grade difference reaches it, the
harvest awards no mastery at all.

# `entries`

```elixir
@spec entries() :: %{
  required(integer()) =&gt; %{differential: integer(), factor: integer()}
}
```

# `positive_factor_count`

```elixir
@spec positive_factor_count() :: non_neg_integer()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
