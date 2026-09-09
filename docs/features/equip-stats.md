# Equipped item stats

Status: constant + static + random + enchant + limit-break stats now aggregate
over equipped gear and apply to the character. Random/enchant/limit-break and
rate-type stats (e.g. perfect guard) are computed; see divergences below.

## Expected behavior

`Context.ItemStats` computes each item's stats via the `calcItemValues` Lua
script (option pick / constant / static tables keyed by id + rarity), sums
them over `character.equips`, and adds the totals to the character's current
and max stats. Applied on field entry and on equip/unequip (broadcasts the
refreshed `set_character_stats`). The base stats are reloaded from the DB on
every apply so the bonuses never stack.

Groups aggregated: `constants`, `statics`, `randoms`, `enchants`,
`limit_break_enchants`. Stat *rates* are applied as a percentage of the current
max; special-value / special-rate stats are carried as stat metadata and
serialized by `character_info`.

## Divergences (still open)

- Random option stats are computed from the option table, but pick id /
  rarity handling for all rarities is not fully verified against the client.
- Enchant / limit-break options: `enchant_level > 0` computes enchant stats,
  but limit-break enchants are currently left empty (`limit_break_enchants: %{}`).
- Special-value stats (from items) are aggregated into `stats.special_values` /
  `special_rates`, but are only *reported* to the client via `character_info`;
  nothing consumes them server-side (the same fields granted by buff status are
  not applied either — see `buff-effects.md`).

## History

Previously equipping an item only moved it between inventory and equipment
slots — the character's combat stats were never recomputed, so a staff granted
no weapon attack.