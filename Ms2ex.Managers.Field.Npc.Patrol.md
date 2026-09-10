# `Ms2ex.Managers.Field.Npc.Patrol`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/npc/patrol.ex#L1)

Npc movement along patrol paths: story npcs walk named patrol paths
(script move_npc) and stay at the last waypoint; the movement math also
seeds the scripted-carry follow-dummy that `Managers.Field.Npc` spawns.

# `advance_patrol`

# `leg_animations`

# `move_npc`

Walks a story npc along a named patrol path (script move_npc): the walk
streams through the control broadcast and the npc stays at the last
waypoint when the path ends.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
