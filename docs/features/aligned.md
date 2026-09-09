# Aligned areas

Systems already verified against the client's expectations. Do not re-open
these unless a specific bug surfaces. Each entry is a brief statement; the
sub-feature docs hold the detail.

- Object ID spaces: app-wide counter for players and mounts; per-field counter
  for npcs, portals, spawn points, buffs, items.
- FieldPickupItem amounts: meso `long`, stamina `int`, other items none.
- ControlNpc dead entries: boss target id 0, real sequence counters, periodic
  corpse re-announcements. 98 NPCs in the ingest carry a hittable corpse; hits
  replay a hit animation via a dedicated control entry. The npc projection
  previously dropped `corpse`, `drop_info` and `custom_exp`, which hid this
  from the server.
- Merets update layout and gain delta.
- State sync: UserSync relay, RideSync relay with ride-state relabeling,
  SyncNumber.
- Mob stat updates: targeted attribute update on the standard stat command.
- Boss-fight packet set: `FieldAddNpc` boss tail (model-name string +
  EffectStr/skill list), `ControlNpc` entries carrying flags bit-1 and the boss
  target-id slot (broadcast immediately on entering battle), and targeted
  Health stat updates while damaged.
- Core skill flow: `SkillUse`/`SkillSync`/`SkillCancel` layouts and the
  `SkillDamage` Target/Damage record entries (TargetRecord = prev uid, uid,
  target id, unknown byte, index). Use carries the real motion point; Target's
  post-direction bool is true and its direction is written as Vector3S shorts
  (was 12-byte floats, corrupting everything after); Heal is the six-int
  record layout (caster, target, owner, hp, sp, ep + animate flag);
  RegionSkill add writes the source id in both int slots.
- Player entity sync: ProxyGameObj update flags rewritten to real per-flag
  payload semantics (Position floats / State short); battle stance also
  broadcasts actor state transitions (casting/idle) through the State flag;
  ControlNpc streams continuously at ~30ms for every npc; boss entries flip
  flags bit-2 and the target-id slot only on aggro (idle->in-battle).
- Inventory tabs: tab derived via item type + subtype + `is_skin`/`is_fragment`,
  matching the client's mapping; the item projection emits
  `property.subtype`/`is_skin`/`is_fragment`.