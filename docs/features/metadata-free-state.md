# Metadata-free manager state

Status: metadata documents are virtual fields on items and get embedded
wherever structs are cached in GenServer state, so manager memory grows with
document sizes instead of entity counts. The item side is lean: the
character manager's cached equip list and the field manager's dropped items
hold rows without metadata and re-read the storage cache at point of use.

## Still holding documents in state

- `Types.Npc` keeps npc metadata per field npc (mob AI, spawns, drop rolls
  and corpses read it)
- the quest manager caches the quest metadata document on every active quest
- `Types.Buff` keeps the full effect document on every active buff

Replacing those with fetch-from-cache-at-use keeps long-lived fields and
combat-heavy characters from accumulating document copies.
