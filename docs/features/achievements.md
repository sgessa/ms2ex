# Achievements & trophies

Status: `Managers.Achievement` (`achievements:<char_id>`) owns every
achievement row in memory; condition events walk the metadata index without
touching the database; updates batch into a periodic flush (also on stop).
Completed field missions activate exploration quests, advance milestone
progress and deliver configured rewards. Grade completions feed quest
conditions (`revise_achieve_*`, `hero_achieve`); stat-point and emote rewards
apply on rank-up while item and title rewards wait for the manual claim.
Riding distance advances `riding` conditions per 150 units. Load packets are
batched per 60 entries.

## Still missing

- skill point rewards (no skill point API yet)
- shared condition-matching limitations: `party_count` / `guild_party_count`
  gates ignored; `target` range gates not evaluated; `stay_cube` needs
  surface/material checks; unique collections need persisted item/fish
  albums; field-mission `progress_maps` / exploration restrictions not
  enforced
- movement/time update throttling must compare the changed condition's
  counter, not the quest's highest counter
- inventory collection counters (`item_collect`, `item_collect_revise`) need
  a persisted collected-item map and `USER_ENV` updates
- condition sources not yet emitted by gameplay: breakables, housing, pets,
  dungeons, PvP, guilds, masteries, gathering/fishing grade conditions, and
  the combat-attribution family (no-damage kills, time attacks, last-hit
  variants, boss/elite/dungeon classifications, assist bonuses)
- economy/item-operation sources: item destroy/break/gear score, shop
  buys/sells, token currencies, enchant/merge/remake/socket/gem results
- social/world sources: guild, club, marriage, mentor, house, banner, UGC,
  profile conditions; PvP/dungeon/festival/minigame event state
- emote and skill-point rewards; client-side unlock rewards (beauty,
  coloring, shop unlocks) and the remaining reward types (`skillpoint`,
  `shop_weapon`, `shop_build`, `shop_ride`, `itemcoloring`, `beauty_*`,
  `etc`)
- achievement counters in character/field profile packets; trophy rankings
- applying the `achievements` migration and re-ingesting metadata per
  deployment before enabling
