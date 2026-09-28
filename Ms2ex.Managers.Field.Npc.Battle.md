# `Ms2ex.Managers.Field.Npc.Battle`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/npc/battle.ex#L1)

Mob aggro and chase: target acquisition, target retention and pathed
movement toward the engaged target.

Target acquisition scans the field's players for anyone inside the mob's
sight band (metadata `distance.sight` with the up/down height slack),
picking the closest. Retention keeps an engaged target while it stays
inside the (wider) last-sight band, dropping it as soon as the player
leaves the field or escapes. Being damaged aggros the attacker directly.

While engaged, the mob paths over the navmesh toward its target and stops
inside its attack range; the chase streams continuously so the client
never sees a stand mid-run. When the target escapes (or leaves the
field), a displaced mob walks back to the point where it spawned —
healing to full and clearing its attacker tags on arrival — while still
scanning, so it can re-engage a player on the way home. Out of battle,
the mob's weighted idle routines roll (`Npc.Idle`): standing, bore
emotes, or a wander leg toward a random point inside its move area
(battle mode `:wander`). The game's per-mob XML decision trees drive
finer combat behavior; this basic AI applies one fixed battle routine
and the tree runtime is a later step (see docs/features/mob-ai.md).

# `t`

```elixir
@type t() :: %{
  mode: :chase | :return | :wander,
  target_id: integer() | nil,
  target_object_id: integer() | nil,
  stop_range: float(),
  path: [Ms2ex.Types.Coord.t()] | nil,
  path_index: non_neg_integer(),
  goal: Ms2ex.Types.Coord.t() | nil,
  next_repath_at: integer(),
  last_move_at: integer(),
  keep_until: integer(),
  no_route_since: integer() | nil,
  cast: map() | nil,
  swing_until: integer() | nil,
  next_attack_at: integer(),
  attack_counter: non_neg_integer(),
  hit_event: map() | nil
}
```

# `aggro`

Engages the mob on the character that damaged it. Direct hit-aggro: the
mob turns on its attacker immediately rather than waiting for the next
proximity scan to notice them.

# `tick`

Per-tick battle update for one mob: scans for a target when idle, then
validates and chases the target while engaged, or walks home while
returning. Returns `{npc, hits}` — the updated npc plus any skill hits
the field must apply. The field state is read-only input.

# `wander_battle`

An idle wander leg toward a static goal: the same pathed-walk machinery
the chase and the trip home ride, minus a target to fight. Arrival hands
the mob back to `Npc.Idle`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
