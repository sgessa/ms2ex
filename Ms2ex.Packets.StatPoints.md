# `Ms2ex.Packets.StatPoints`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/packets/game/stat_points.ex#L1)

# `allocation`

Sends the current AP allocation state.
`allocated` is an atom-keyed map, e.g. `%{strength: 3, health: 2}`.
`total` is the total available points (sum of all sources).

# `sources`

Sends the AP source totals. Triggers the "Received AP" in-game notification.
`sources` is an atom-keyed map, e.g. `%{trophy: 5, command: 10, ...}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
