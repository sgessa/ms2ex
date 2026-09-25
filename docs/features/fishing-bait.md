# Fishing bait & autobait

Status: bait/lure items ingest with `property.tag = :fishing_lure`; fish
metadata includes lure rows and `bait_effect_ids`; using a bait item skill
applies the timed lure buff, consumes the inventory stack, pushes the shared
bait cooldown, and fishing rolls can use the active lure buff.

## Still missing

- the auto-fishing dialog's bait-slot amount does not refresh while a stack
  drains: every bait use is client-initiated and the `INVENTORY_ITEM` update
  correctly refreshes the inventory tab, but the dialog caches the amount
  from when the bait was slotted and only corrects on remove + re-add. No
  frame of the `FISHING` family is known to refresh the slot (the frame
  family is fully mapped apart from an album-simulation mode); finding the
  refresh frame needs a packet capture of the live client during baited
  auto-fishing
- the "Use autobait" toggle has no server-side model; it likely needs state
  for auto-reapplying a lure when the active timed bait buff expires
- the dedicated bait-slot add/remove frames are unknown — the client needs
  to be reversed around bait slot add/remove, bait use, and the autobait
  toggle
