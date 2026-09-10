# FieldAddItem (0x002B)

Packet layout:

- Header tail after rarity: `short`, `bool FixedPosition`, `bool`.
- Non-meso drops append a full item class (`Item.WriteTo`).
- Mesos (90000001..90000003) append nothing.

History: the tail was a stray int (`21`), mob-drop currency items carried a
hand-written "special" blob, and player drops reused the inventory packet
layout — all of which over-consumed on the client and corrupted nearby entity
state (unhittable field bosses, minimap icons stuck at drop locations, missing
death animations).

Status: headers fixed on both clauses; player drops serialize a faithful
default-state port of the item class; mob drops of regular items append the
same full item class (previously they appended nothing, so non-currency mob
drops never rendered).

## Remaining deviations

1. **Trailing zero padding** (~64 ints) is appended to both clauses. The
   client sends none. It acts as an over-consumption buffer while the exact
   expected tail length for this client build remains unverified.
2. **Mob-drop currency blob** still uses the legacy `count=1` + entry payload.
   It renders and picks up correctly with the corrected header, but the entry
   fields' true semantics are unknown.
3. **Mesos** append nothing (matching the client); SP/stamina/merets keep
   the legacy currency blob rather than the full item class.