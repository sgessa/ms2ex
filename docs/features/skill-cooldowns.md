# Skill cooldowns

Status: implemented.

On a successful cast the cooldown is derived from the level's
`cooldown_time` (seconds) plus `state.cooldown_group_id` /
`state.recharge_max_count` and stored in the character's live state
(`Managers.Character`). `Packets.SkillCooldown` (send `0x43`, byte count +
{skill id, group id, end tick, charges} records) is sent on field re-entry,
pruning expired entries.

The skill projection must emit the cooldown fields (`level.cooldown_time`,
`state.cooldown_group_id`, `state.recharge_max_count`) — previously the level
`condition` was an opaque empty list and `state` only carried
`in_battle`/`state`, so the server computed no cooldowns and never sent a list
to restore on field change. Requires a rebuilt ingest + fresh cache + server
restart.

`Ms2ex.sync_ticks()` returns monotonic ms since app compile: the raw OTP clock
base is negative on this VM, so every client-facing tick (time sync, buff start
ticks, cooldown end ticks) went out negative and clients treated cooldowns as
already expired (the client only re-reads the server's cooldown list on field
load). The positive base also lets the client tick echo match
`session.server_tick`.

Buff-triggered resets: a buff whose `update.reset_cooldown` lists skill ids
clears those cooldowns (stored end tick 0 via `set_skill_cooldown`) and pushes
a `SkillCooldown` record to the owner; requires the projected
`update.reset_cooldown` field (fresh cache).

`SkillResetCooldown` (send `0x44`) is mapped but never sent, so it stays
unwired.