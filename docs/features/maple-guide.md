# Maple Guide

Status: working baseline — the guide book UI's "start" action moves the
character to the guide's training map.

The guide book is a client-side UI listing training guides (mounts, musical
instruments, life skills, mining, farming, ...). Each guide is an entry in
the `learningquest.xml` table; the quests themselves are normal quests
started from the NPCs on the guide's destination map, so the server's role is
requirement gating plus the trip there.

## Flow

The guide book's "start" button sends `Quest` with subcommand `0x10` and the
guide entry id. The quest manager resolves the entry and moves the character
when all of these hold:

- the entry exists (unknown ids are a silent no-op)
- the character's level meets the entry's `required_level`
- the entry's `quest_id` (its repeat gate) has not been completed before — a
  started quest does not block; only a completed one does
- the entry does not lead to the private residence (`go_to_map_id`
  62000000): guides ending there are a no-op until residences exist

On success the character changes field to `go_to_map_id`, placed at
`go_to_portal_id` when the map has that portal, otherwise at the map's
default spawn. A guide's quest is not started by the server — the NPC flow
on the destination map handles that.

The guide maps' trigger scripts drive the tutorial (cutscenes, race gates,
the completion condition). Their `user_detected`/`quest_user_detected`
boxes read the position the client reports, which while mounted is the
ride-sync channel — ride sync feeds the same live-position tracking as
normal movement so mounted characters still trip trigger boxes.

## Leaving the guide map

A guide map's exit portal (its script opens it once the guide's quest is
completed) carries no destination of its own — `target_map_id` 0. Walking
through it sends the character to their return map: the last map entered
that declared an `enter_return_id`, seeded with the job's starting field
at creation. That slot is the character's persisted `map_id` — relogging
from a map that declares none (a guide map, most instances) lands at the
hub the character came from too, so the machine never has to re-run a
tutorial whose quest is already completed. A slot naming a map missing
from storage falls back to Lith Harbor (2000062).

## Data

`table:learningquest.xml` (ingested from the client table of the same name),
keyed by guide entry id:

- `category` — guide book category the client groups the entry under
- `required_level` — minimum character level to start the guide
- `quest_id` — the guide's repeat-gate quest (completed ⇒ guide unusable)
- `required_map_id` — client-side visibility gate; not enforced server-side
- `go_to_map_id` / `go_to_portal_id` — destination map and arrival portal

## Still missing

- migration into the private residence for guides with `go_to_map_id`
  62000000 (needs the home system)
