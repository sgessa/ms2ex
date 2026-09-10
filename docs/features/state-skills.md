# State skills (recv 0x21)

Status: recv `0x21` routes to `GameHandlers.StateSkill`, which parses the
request, validates the skill metadata exists and that a referenced item uid
is in the character's inventory, and relays `Packets.StateSkill` (send
`0x42`) to the field.

## Which skills are state skills

The client sends `0x21` when the actor ENTERS a movement/exploration state;
the `state` int is the ActorState being entered and `item_uid` covers mount
items:

- `20000001` Swift Swim (ActorState 28, swimming) — 20 stamina per tick
- `20000011` Wall Climbing (29) / `19900011` High Speed Flying (30) — no cost
- emotes (19xxxxxx) and consumables (80xxxxxx) carry states too but no cost

So the practical test is swimming: passive swimming costs nothing — the
drained skill is **Swift Swim (Ctrl while swimming, 20000001)**. In-game
verified: holding Ctrl drains 20 stamina per ~0.9s tick; releasing Ctrl ends
the drain (the client sends a non-start `0x21`, which cancels server-side).

## Resource costs

State-skill casts now flow through the character manager
(`Managers.Character.Skill.cast_state_skill`): the cast is gated on having
enough SP/stamina (rejected otherwise, no relay), then both are drained and
a full stat refresh shows the initial consumption.

After a successful cast the manager arms a per-tick drain loop
(`{:state_skill_tick, cast_id}` messages to the character GenServer):

- every tick re-validates the costs and drains again, broadcasting the
  updated SP/stamina
- the stance is cancelled when SP/stamina run out, when the actor is dead,
  or when a new StateSkill packet arrives (state transition or a non-start
  function byte)
- an actor holds at most one state skill; arming a new one cancels the old
- a repeated packet for the same cast id + state is treated as a refresh and
  does not double-drain
- a stale tick (cast id no longer active) dies out silently

Server-side cancellation relays `Packets.StateSkill` with state 0 so the
field sees the actor leave the skill state; the cancelling client keeps its
own stance UI until it observes the resource drain.

## Deferred

- Regular-cast counterpart behaviour (buffs, cooldowns, battle stance) is
  not applied on state-skill casts; only costs are handled.

## Cancel on leaving the movement state

The client sends no observable cancel on releasing Ctrl; the first swim test
showed the drain running on while stamina refilled underneath it. The server disambiguates by comparing the skill's ActorState against the
state-synced actor state every tick. ms2ex already stores the synced state
from user syncs as `character.animation`, so the drain tick now cancels when
`skill.state.state != character.animation` (only checked for non-zero skill
states). Verified enum mapping: `Swim = 27`, `SwimDash = 28`, `Climb = 29`,
`Glide = 30`.

## Regen fix (exposed by the drain)

The first swim test showed stamina never recovering after release: the
`dead?` guard on `Character.Stats.regen/2` was inverted (added in the
manager refactor #88) — living characters returned early and never
regenerated HP/SP/stamina, while dead ones fell through to the regen logic.
Fixed to skip the dead; passive regen re-arms from any stat decrease and
cycles until the stat is full.

The second test showed regen racing the drain: stamina never depleted while
boosting. Regen of the drained stat is suspended after consumption — server
constants `RecoveryHPWaitTick`/`RecoverySPWaitTick`/`RecoveryEPWaitTick`, all
1000 in the live `table/Server/constants.xml`. The ingest now projects that
table as `table:server.constants.xml` (897 snake_cased constants, acronym
aware: HP stays hp) and `Character.Stats` reads the per-stat wait from it
with a 1000ms fallback for absent metadata. Swift Swim drains every ~0.9s <
the 1s wait, so stamina depletes while boosting and refills ~1s after
release.

## Cadence

`Types.SkillCast.drain_interval/1` reads the projected motion
`motion_property.sequence_speed` (ingest projects it; `--probe-skill` prints
it as `motion: seq=... speed=...`). Verified live after the re-ingest:
Forward Roll (10000041) drains 40 stamina every 800ms, Snail Throw (10000021)
3 spirit every 1000ms. Metadata ingested before the projection still falls
back to once per second.