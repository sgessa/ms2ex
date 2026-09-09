# Character-owned inventory manager

Status: `Ms2ex.Managers.Inventory` (`inventories:<char_id>`, like the quest
manager) owns every item row and tab size of a character in memory — lean
rows without metadata documents. `Context.Inventory` delegates reads and
mutations (add/stack, consume, cross-stack consumption, delete, generic
updates, swap, sort, tab expansion) and slot allocation to the manager when
it is alive, falling back to the direct DB path otherwise (login-server
flows, tests); write-through keeps rows and memory coherent. Equip
transitions route their item moves through the manager, and the character's
cached equip list is refreshed from it.

## Still missing

- quest completion still wraps turn-in consumption in a caller-side
  transaction; with the manager alive, item writes no longer join it —
  completion should be restructured into in-process ordering inside the
  manager (consume turn-ins + grant item rewards as one manager call)
- the character manager's cached equip list is a second copy of the equip
  subset — could be dropped in favor of reading the inventory owner's state
- shops / trades / storage / mail item flows should route through the
  manager as they arrive
- explicitly rejected approach: read-caches layered over the DB (two sources
  of truth, none of the ownership benefits)
