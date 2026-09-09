# Quest flow

Status: a working baseline — quest opcodes, state serialization, persistence
with live condition counters, an ingest projection with a quest index, npc
quest lists, talk-script dialogue selection (accept/progress/complete, quest
vs plain talk choice menus), auto-start seeding, and reward delivery (exp,
mesos, treva, rue, essential items).

Condition hooks fire from gameplay: mob kills (`npc`), skill casts, level
ups, field pickups, inventory acquisition, emote use (matched on the
client-sent animation key), taxi rides, meso pickups, chat, tombstone hits,
buddy requests, exp gain. Progress matching follows the metadata layout:
code-parameter id/string containment plus target minimum-value /
allowed-value gates.

Completion and acceptance commit the quest row, turn-in item consumption and
item rewards atomically; exp and currencies are granted post-commit.
Condition-counter changes accumulate in memory and batch into a periodic
flush. The quest manager state stores only persisted row data (state, times,
track flag, condition counters); quest and condition documents resolve from
the ETS cache. Non-forfeitable quests refuse abandon; the expiration sweep
drops expired rows in one statement per owner scope; go-to-npc travel moves
the character to the quest's destination map. Event-tagged quests never
start on their own.

## Still missing

- multi-page dialogue walking within one script state (Continue index
  tracking) and script functions (rewards/portal/cutscene side effects
  inside dialogues)
- interact object lifecycle beyond the state machine: additional effects are
  invoked, drop boxes roll, `modify_code` shifts a buff's remaining
  duration; interact-driven mob spawns are not implemented
- condition sources for breakables (`breakable_object`), triggers, and the
  long-tail condition types
- selective rewards and the remaining reward-side edge cases
- Maple Navigator: request/response packets, remote completion, map guidance
- chapter rewards, job-advance hooks, and the remaining quest subcommands
