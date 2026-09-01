# Refactoring Roadmap

## 1. Apply `Managed` to remaining named-process managers

`Managers.Managed` is implemented and `Managers.Character` uses it.
The same `call`/`cast`/`process_name` boilerplate still exists in:

- `GroupChat`
- `PartyServer`
- `Buff`

Each needs `use Ms2ex.Managers.Managed, prefix: "...", key: :id` and removal of its hand-coded `call/2`, `cast/2`, and `process_name/1`.

---

## 2. Separate packet building from context/business logic

Several context modules (`Context.Field`, `Context.Inventory`) call
`Packets.*` directly. Context should be packet-agnostic; callers (handlers,
managers) should own the packet sends.

Affected modules include `Context.Field.broadcast_stats`, which calls
`Packets.Stats` – this is fine as a field-level broadcast helper but is a
pattern worth documenting as the limit of how far context can reach into packets.

---

## 3. Normalise `Context.Characters` (it mixes concerns)

`Context.Characters` has:
- CRUD (`get`, `update`, `delete`, `create`) – correct
- Stat-point persistence (`update_stat_points`) – belongs here
- Helpers that call other contexts (`load_equips`, `load_skills`, `maybe_discover_map`)

`load_equips` and `load_skills` are convenience loaders that return an enriched
character. They are only called at login and in tests. Consider moving them to
`Context.CharacterStats` or a dedicated `Context.CharacterLoader` to keep
`Context.Characters` focused on persistence.

---

## 4. Existing TODOs worth scheduling

| Location | Note |
|----------|------|
| `managers/character.ex:14` | `lookup_by_name` does a direct SQL query – should use the registry |
| `context/inventory.ex:300` | Inventory slots are not read from DB |
| `managers/party_server.ex:147` | Start-vote-kick packet not sent |
| `managers/character/revival.ex:131` | Free-revive coupon not consumed |
