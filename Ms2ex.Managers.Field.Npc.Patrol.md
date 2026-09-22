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

Attempts (or restarts) the leg toward the patrol's current waypoint.

A leg that cannot start — no connected navmesh route, or no approach
animation the model can play — does not end the patrol: that would freeze
story npcs mid-script on maps whose mesh has coverage gaps. Instead the
npc stands in its idle pose for a beat while the patrol advances past the
waypoint, and the next leg is attempted once the beat elapses (loop
patrols wrap and keep attempting; only the last waypoint of a non-loop
patrol ends the patrol when it fails to start). The one exception is the
scripted-carry dummy: its walk is choreographed client-side and the carry
must complete, so an unroutable leg falls back to the authored straight
line instead of stalling the script mid-carry.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
