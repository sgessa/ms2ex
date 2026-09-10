# Party damage meter

Status: open. The client's party DPS meter never updates because the server
never feeds it.

- the client requests the meter via recv `0x57` (DpsMode) and expects
  periodic send `0x88` (DpsStat) with per-member damage totals
- ms2ex drops `0x57` as an unknown packet and never sends `0x88`
- field `SkillDamage` broadcasts already reach party members byte-correctly,
  so this is purely missing server-side damage accumulation + the `DpsStat`
  flow
