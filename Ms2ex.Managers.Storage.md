# `Ms2ex.Managers.Storage`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/storage.ex#L1)

Per-account bank storage: the item rows (account-owned `inventory_items`),
the stored mesos and the purchased slot expansion. The process lives only
while the storage window is open — the client's load request starts it and
its close request stops it; every mutation persists immediately.

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `close`

Closes the storage window (stops the process).

# `delete`

Destroys a stored item.

# `deposit`

Moves an inventory item (or part of it) into storage.

# `deposit_mesos`

# `expand`

Buys one more storage row with merets.

# `load`

Sends the full storage window contents.

# `move`

Swaps a storage item with whatever occupies the target slot.

# `sort`

Compacts the storage rows by item id.

# `start`

# `stop`

# `withdraw`

Moves a storage item (or part of it) back into the inventory.

# `withdraw_mesos`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
