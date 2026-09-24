# `Ms2ex.Context.DailyReset`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/daily_reset.ex#L1)

Resets per-character daily state when the midnight worker fires.

The single `reset/0` entry point bulk-zeroes the persisted daily columns for
every character, then clears the in-memory state and refreshes the client
gauge for each connected player. Add new daily fields and their refresh
packets here as they appear.

# `reset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
