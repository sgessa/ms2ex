# Party damage meter

Status: partial. The server now accepts `DpsMode`, accumulates successful player
damage, and periodically sends `DpsStat` totals while the meter is enabled.

- the client requests the meter via recv `0x57` (DpsMode) and expects
  periodic send `0x88` (DpsStat) with per-member damage totals
- field `SkillDamage` broadcasts already reach party members byte-correctly
- vote-kick now has a timed majority-vote flow alongside the DPS work
