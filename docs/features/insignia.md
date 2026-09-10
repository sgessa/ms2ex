# Name-tag insignias

Status: the name tag symbol flow is complete — the id is validated against
`nametagsymbol.xml`, persisted, its buff swapped on change, and the display
flag broadcast and written into the field-add-user payload. Six of the twelve
condition types are evaluated (`title`, `level`, `enchant`, `trophy_point`,
`adventure_level`, `vip`).

## Still missing

- `burning` and `survival_level` never display (one insignia each). Each
  needs a system the server has no model for: burning-event characters and
  Maple Survival levels. `tencentvip`, `gm` and `tgp` exist in the enum but
  no insignia uses them
- conditions are only evaluated when the insignia is equipped, so a symbol
  keeps showing after its condition lapses (premium expiring, enchanted gear
  removed, a level reset). A re-check would need a hook per condition type
- the thresholds are hardcoded (level 50, 1000 trophy points, prestige 100,
  12 enchants / rarity > 3). Only `title` reads the table's `code` column,
  so the rest cannot be retuned from metadata
