# Code organization: types, enums, helpers

A proposal for restructuring `lib/ms2ex` module placement, driven by one
criterion. This is a design note — the actual moves are a mass refactoring
to do later (see "Migration plan").

## The rule

> A module belongs in `types/` iff it **defines a data shape** (a `defstruct`,
> an `Ecto.Schema`, an enum value set, or a marshalled value object such as a
> tuple + constructors). A module whose primary job is **computation,
> serialization, or bit arithmetic on data** does not.

Enums are data shapes (the `enums/` directory is fine as-is). Structs are
data shapes. A module full of `def`s that read/write packets, combine
flags, or transform values is behavior, not a type.

## Current audit (`lib/ms2ex/types/`)

| Module | Kind | Verdict |
| --- | --- | --- |
| `Types.Buff` | struct | keep |
| `Types.Coord`, `Types.CoordF` | structs | keep |
| `Types.FieldNpc` | struct | keep |
| `Types.Hair` | struct | keep |
| `Types.ItemStat`, `Types.ItemStats` | structs | keep |
| `Types.Npc` | struct | keep |
| `Types.Party` | struct | keep |
| `Types.QuickSlot` | struct | keep |
| `Types.SkillCast` | struct | keep |
| `Types.SyncState` | Ecto.Schema (packet sync state) | keep (data shape) |
| `EctoTypes.Term` | custom Ecto type | keep (a real type) |
| `Types.Color`, `Types.ItemColor`, `Types.SkinColor` | tuple value + packet read/write | **split**: keep `Color` as a value type; move the packet read/write to a packet helper |
| `Types.HairData` | tuple builder | borderline — keep (value object) or fold into `Types.Hair` |
| `TransferFlags` (file `transfer_flag.ex`, module `Ms2ex.TransferFlags`) | bit arithmetic on integers | **move** to a helpers namespace |

### Modules already relocated

- `Context.ItemTransfer` — transfer-flag + bind computation (was
  `Types.ItemTransfer`). Belongs in `context/` with the other
  `Context.Item*` behavior modules (`ItemConstantStats`, `ItemStaticStats`,
  `ItemRandomStats`, `ItemEnchantStats`, `ItemTypes`).

## Proposed target layout

```
lib/ms2ex/
├── types/            # data shapes only (structs, Ecto schemas, value objects)
├── enums/            # enum value sets (already clean; enums are types)
├── schema/           # persisted DB schemas
├── helpers/          # NEW: generic function-only helpers
│   ├── transfer_flags.ex     # Ms2ex.Helpers.TransferFlags (moved)
│   └── color.ex              # packet read/write for colors (moved)
├── context/          # domain behavior / use-cases (functions on types)
├── packets/          # wire serialization (packet builders)
├── managers/         # GenServers / processes
├── handlers/         # network handlers
└── storage/          # Redis metadata cache + table accessors
```

### Where behavior lives

- **Domain behavior** (business rules, use-cases): `context/`. Already the
  home for `Items`, `Inventory`, `Mobs`, `Equips`, `ItemTransfer`, etc.
- **Generic non-domain helpers** (bit ops, math, small utilities): a new
  `helpers/` directory (`Ms2ex.Helpers.*`). `TransferFlags` is the
  canonical example — it's integer bit arithmetic, not domain logic.
- **Wire serialization** (packet read/write of values): `packets/`
  (e.g. `Ms2ex.Packets.Helpers.Color`). `Types.Color` keeps the value
  shape + `build/4`; the `get_color`/`put_color` packet functions move.

### Things that stay put

- `enums/` — enum value sets (`TransferType`, `Gender`, `Job`, ...). They
  are types; a separate namespace keeps `types/` small. (Optionally fold
  into `types/` later; not recommended — `Enums.*` reads better.)
- `schema/` — Ecto schemas backed by DB rows.
- `context/` — already correct.

## Rationale

1. **Discoverability**: "is this a value I can hold, or code that does
   something?" answers where to look for it. `types/` becomes a catalog of
   data shapes; `context/` + `helpers/` a catalog of behavior.
2. **Package size**: `Types` stops accumulating one-liner helpers and
   stays a real type system; `Context.Items` stays lean by delegating to
   `Context.Item*` modules.
3. **Data/behavior separation**: keep data documents apart from behavior
   modules, with `types/`/`enums/`/`schema/` vs `context/`/`helpers/`.

## Migration plan (do later, in small mechanical commits)

1. `Ms2ex.TransferFlags` → `Ms2ex.Helpers.TransferFlags`
   (`lib/ms2ex/helpers/transfer_flags.ex`); update the 3 callers
   (`Context.ItemTransfer`, `handlers/game/inventory.ex`,
   `commands/commands.ex`).
2. `Types.Color` / `Types.ItemColor` / `Types.SkinColor`: keep the value
   shapes, move packet read/write into `Packets.Helpers.Color`; update
   callers in `packets/game/field_add_user.ex`,
   `packets/game/inventory_item.ex`, `packets/login/character_list.ex`,
   `handlers/login/character_management.ex`.
3. Optional: fold `Types.HairData` into `Types.Hair`.
4. Move `EctoTypes` under `types/` (already there) — no change.

Each step is an isolated move + caller update, so it can be done one PR at
a time without a big bang.