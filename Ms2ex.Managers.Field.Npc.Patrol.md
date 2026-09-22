# `Ms2ex.Managers.Field.Npc.Patrol`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/npc/patrol.ex#L1)

Npc movement along patrol paths: story npcs walk named patrol paths
(script move_npc) and stay at the last waypoint; the movement math also
seeds the scripted-carry follow-dummy that `Managers.Field.Npc` spawns.

# `advance_patrol`

# `leg_animations`

# `leg_speed`

# `leg_speeds`

# `move_npc`

Walks a story npc along a named patrol path (script move_npc): the walk
streams through the control broadcast; loop patrols cycle their waypoints
forever, and a non-loop patrol leaves the npc at the last waypoint.

# `npc_speed`

# `start_leg`

Resolves how the current authored waypoint is reached: over the navmesh
graph, walking ramps and stairs instead of a straight line through the
air. Returns `:error` when no connected route exists (unresolved nif
props leave coverage gaps) — the caller then leaves the npc standing
instead of walking a straight line that can float above the terrain.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
