# MS2EX Roadmap

Open and incomplete features, grouped by priority. Each entry links to its
feature document under [features/](features/) with the technical detail —
how the system works today and what is still needed. Completed work lives in
[CHANGELOG.md](CHANGELOG.md). Client metadata projections are documented in
[CLIENT_METADATA.md](CLIENT_METADATA.md).

Status markers: **[Partial]** — some pieces are in place; **[Open]** — not
started.

---

## P1 — Core combat loop

- [Field manager](features/field-manager.md) — [Partial]
- [Player death & revive](features/player-death-revive.md) — [Partial]
- [Mob AI: aggro, chase & attack](features/mob-ai.md) — [Open]
- [Damage pipeline](features/damage-pipeline.md) — [Partial]
- [Mob spawn cycles](features/mob-spawn-cycles.md) — [Partial]

## P2 — Combat systems depth

- [Buff & effect system gaps](features/buff-effects.md) — [Partial]
- [Region & splash attacks](features/region-splash.md) — [Partial]
- [Quest flow](features/quest-flow.md) — [Partial]
- [Achievements & trophies](features/achievements.md) — [Partial]
- [Trigger-script runtime](features/trigger-runtime.md) — [Partial]
- [Character tutorial](features/character-tutorial.md) — [Partial]
- [Guild system](features/guild-system.md) — [Partial]
- [Housing & UGC cube system](features/housing-ugc-cubes.md) — [Open]
- [User generated content](features/ugc.md) — [Partial]
- [Music performances](features/music-performances.md) — [Partial]
- [Fishing bait & autobait](features/fishing-bait.md) — [Partial]
- [Item boxes & use-item functions](features/item-boxes.md) — [Partial]
- [Item systems: gem sockets, pet items, gacha](features/item-systems.md) — [Open]
- [Premium Club](features/premium-club.md) — [Partial]
- [Badge system](features/badge-system.md) — [Partial]
- [Name-tag insignias](features/insignia.md) — [Partial]
- [Party damage meter](features/party-dps-meter.md) — [Open]

## P3 — Client parity & serialization

- [Join-flow packet audit](features/join-flow.md) — [Partial]
- [Drop & field-item serialization](features/drops-serialization.md) — [Open]
- [Navmesh position validation](features/navmesh.md) — [Partial]

## P4 — Architecture

- [Character-owned inventory manager](features/inventory-manager.md) — [Partial]
- [Metadata-free manager state](features/metadata-free-state.md) — [Partial]
- [Code organization](features/code-organization.md) — [Partial]

---

Feature documentation for completed systems (how they work, no open work
tracked): [state skills](features/state-skills.md),
[skill cooldowns](features/skill-cooldowns.md),
[monster drops](features/monster-drops.md),
[equipment stats](features/equip-stats.md),
[skill coverage gaps](features/skill-gaps.md), and
[verified packet areas](features/aligned.md).
