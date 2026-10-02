# `Ms2ex.Context.Storages`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/storages.ex#L1)

Persists the per-account bank storage: stored mesos and slot expansion
(`Schema.AccountStorage`) and its item rows. Storage items live in
`inventory_items` owned by the account (`character_id` nil, `account_id`
set), so they never collide with character inventory queries.

# `create_info`

# `create_item`

# `delete_item`

# `get_info`

# `list_items`

# `save_info`

# `update_amount`

# `update_item_slot`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
