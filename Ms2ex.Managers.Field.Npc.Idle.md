# `Ms2ex.Managers.Field.Npc.Idle`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/npc/idle.ex#L1)

Mob idle behavior between fights: while out of battle a mob follows its
weighted idle routines — standing, playing a bore emote, or walking to a
random walkable point inside its `move_area` around the spawn point. A
mob without a move area (or without locomotion) stays at its post.

The routines come from the npc's `action.actions` weighted list (each
entry names an animation sequence and a probability): `Idle_*` keeps the
mob standing, `Bore_*` plays the sequence once as an emote, and
`Walk_*` / `Run_*` walk a wander leg. Wander movement rides the battle
walk machinery through the `:wander` battle mode.

# `t`

```elixir
@type t() :: %{task: :stand | :emote, until: integer()}
```

# `arrive`

Ends a completed wander leg: back to standing, without touching health
or attacker tags (only the trip home heals).

# `tick`

Advances one idle mob: a stand or emote holds until its beat elapses,
then the next routine is rolled from the metadata's weighted actions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
