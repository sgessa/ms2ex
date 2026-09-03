# `mix maple.ugc.clear`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/mix/tasks/maple/ugc/clear.ex#L1)

Removes the configured UGC data directory.

Uploaded files are keyed by ids the database hands out, so they are only
meaningful next to the database that produced them. `mix ecto.reset` runs
this task for that reason.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
