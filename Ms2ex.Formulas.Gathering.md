# `Ms2ex.Formulas.Gathering`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/formulas/gathering.ex#L1)

Gathering success rate, ported from the client's
`calcGatheringObjectSuccessRate`.

A node is a guaranteed hit until it was harvested `high_rate_limit_count`
times; past that the rate falls off quadratically until it reaches zero.
Harvesting in someone else's home cuts both limits to a fifth.

# `success_rate`

```elixir
@spec success_rate(non_neg_integer(), integer(), integer(), boolean()) :: float()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
