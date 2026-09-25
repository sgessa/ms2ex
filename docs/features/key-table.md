# Key table (key binds & quick slots)

Status: working — key binds and quick slots are owned in memory per
character, persisted to their own tables, and restored server-
authoritatively at login.

The KeyTable packet family covers two related pieces of client config:
**key binds** (which key triggers which action) and **quick slots** (which
skill/item sits in which hot bar slot). Both follow the same lifecycle: the
client owns its UI, the server stores the authoritative layout, and the two
converge at login and on explicit sync requests.

## Storage

- `hot_bars` — one row per bar (the character's bars are created at
  character creation, first active), `quick_slots` serialized as a term
  column. Owned by `Ms2ex.Managers.HotBars`.
- `character_configs` — one row per character holding client config that is
  read once per login and rewritten in bulk: `key_binds` (a map keyed by
  key code of `Ms2ex.Types.KeyBind` entries), `guide_records` (guide-popup
  progress), `gathering_counts` (harvest counters driving the success rate)
  and `instant_revive_count` (the daily instant-revive allowance). The row is
  created together with the character, so `Ms2ex.Context.CharacterConfigs.get/1`
  can read it fail-fast; the row is written by two owners, each through plain
  updates of its own columns: the character-config manager persists the client
  config fields, the mastery manager persists the harvest counters and the
  claimed grade rewards. Neither depends on the other's cached row.

## Config manager

`Ms2ex.Managers.CharacterConfig` (started at login, stopped on disconnect)
loads the character's config once — the hot bar rows and the
`character_configs` row — and serves field enter, quick-slot moves, active
-bar switches, key-bind syncs and guide reports from memory.
Every mutation is applied to memory, then persisted from the row's
previous state through `Ms2ex.Context.HotBars` (`update_quick_slots/2`,
`set_active/2`) and `Ms2ex.Context.CharacterConfigs` (`update/2`); the
persisted rows returned by the
contexts replace the manager's cached ones, so memory always matches the
database.

Quick-slot semantics (`Schema.HotBar`):

- moving a quick slot onto a position it already occupies swaps the two
  entries
- slots 22–24 are the client's page controls; a move target outside the
  assignable range lands on the first free slot in the placement order
  (`4, 5, 6, 7, 0, 1, ...`), replacing slot 0 when the bar is full
- removal matches on skill id **and** item uid, so bound item slots (emotes,
  consumables) never collide with pure-skill slots

`update_hotbar_skills/1` syncs the bars with the active skill tab: unlearned
pure-skill slots are cleared from every bar (bound item slots survive) and
learned in-battle actives missing from the active bar are placed in the next
free slot. Changed bars only are persisted. It runs when a fresh character
(no saved layout) first enters a field and after a skill-build save/preset.

Guide reports merge into the saved progress immediately. Harvest counters
belong to the mastery manager (`Ms2ex.Managers.Mastery`), the dedicated
GenServer for the life-skill domain (mastery values, claimed rewards,
harvest counters): the harvest flow reads and bumps them there, and each
bump upserts the counter column. The instant-revive flow reads and bumps
`instant_revive_count` through the config manager. The daily reset
bulk-clears both columns, then each owning manager drops its cached daily
state and pushes the matching client gauge itself (the config manager holds
the sender session pid for this).

## Packet flow

Client → server (`Ms2ex.GameHandlers.KeyTable`):

- `0x1`/`0x2` set key binds — each entry is upserted by key code and the
  whole table is rewritten to `character_configs`
- `0x3`/`0x4` move/add quick slot, `0x5` remove — through the manager, the
  updated bars are sent back
- `0x7` key-table re-sync request — a skill-set buff (e.g. the tutorial's
  training swap) changing or reverting makes the client drop the swapped bar
  entries and ask for the authoritative layout back; answered with the saved
  bars
- `0x8` set active hot bar — flag flip, persisted

Server → client (`Ms2ex.Packets.KeyTable`):

- login sends the full **Load** (saved binds + active bar + bars) when key
  binds exist; a brand-new character gets **LoadDefault** instead, letting
  the client apply its own defaults and sync them back (which fills the
  saved key binds)
- field enter re-sends the bars so the client initializes its UI before the
  field-enter stream

## Still missing

- Reset Skill Build (`0xA`) does not reset skills yet, so it also skips the
  hot-bar re-sync the save path performs (TODO in the job handler)
- KeyTable client command `0x6` is unhandled (no observed behavior)
