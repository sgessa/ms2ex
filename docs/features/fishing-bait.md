# Fishing bait & autobait

Status: bait/lure items ingest with `property.tag = :fishing_lure`; fish
metadata includes lure rows and `bait_effect_ids`; using a bait item skill
applies the timed lure buff, consumes the inventory stack, pushes the shared
bait cooldown, and fishing rolls can use the active lure buff.

## Still missing

- the client bait-slot amount does not refresh when the inventory stack is
  consumed; the normal `INVENTORY_ITEM` update refreshes the inventory tab,
  but the fishing bait slot keeps its cached count until the bait is removed
  and re-added
- the "Use autobait" toggle has no server-side model; it likely needs state
  for auto-reapplying a lure when the active timed bait buff expires
- the dedicated bait-slot packet or fishing subcommand is unknown — the
  client needs to be reversed around bait slot add/remove, bait use, and the
  autobait toggle
