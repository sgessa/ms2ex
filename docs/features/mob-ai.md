# Mob AI: aggro, chase & attack

Status: not started. Mobs never target players — they do not aggro, chase or
attack, so mob→player damage and its stat broadcasts do not exist. The player
can fight mobs; mobs cannot fight back.

## What is needed

- a per-mob AI state machine (idle → aggro → chase → attack → return), driven
  from the field tick like the existing spawn cycles
- target selection: players inside the mob's sight range, with the mob's
  aggro rules (first attacker vs proximity)
- movement over the navmesh toward the target (npc pathing queries are the
  missing navmesh piece — see navmesh.md)
- attack skill selection from the npc metadata's skill list, with cooldowns
  and ranges
- player damage application: the existing damage pipeline in reverse
  (mob as attacker), death flow for players already exists
  (player-death-revive.md)

## Interactions with existing systems

- mob stat updates (`ControlNpc` targeted attributes) already broadcast; the
  same channel carries the mob's state while chasing/attacking
- boss bar arming is tied to combat engagement (see boss-hp-bar internal
  notes): mobs engaging instantly is expected behavior
- trigger conditions like `npc_detected` already read npc positions from
  state, so AI movement feeds them for free
