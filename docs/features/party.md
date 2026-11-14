# Party

Status: mostly working. Invite/accept/leave/kick, leader promotion, ready
check, vote kick, the party finder, and the party damage meter all work. The
party recall (summon scroll) flow is implemented.

## Recall (party summon)

The party menu's recall button pulls party members to the caster's field.
The client runs a five-second cast at the caster before sending anything, so
the server only ever sees the finished request.

Flow:

1. The caster presses the recall button. The client consumes a held recall
   scroll, or buys one for the meret price first; either way the server
   receives `Party` (recv `0x2C`) mode `0x1D` with no payload.
2. Before consuming anything the server checks that the requester is the
   party leader, that no recall is pending, and that at least one member is
   promptable: online, alive, in a field, on a different field than the
   caster, and still in the party.
3. The server consumes/buys the scroll in the caster's inventory, then sends
   `RecallScroll` (send `0xBE`) mode `1` to every promptable member:
   `byte slot` (the client's notify-clip index: 0 guild, 1 party, 2 wedding),
   `ustring caster name`, `int` (stored, unused), `int map id`, `int`
   (stored, unused), `long deadline` — **unix seconds** on the client's
   server-time clock (the int64 `serverTime` of the time-sync packet). The
   client shows a bottom-centre prompt in the matching clip with a countdown
   that turns red in the last ten seconds. A deadline in any other unit
   reads as already expired and the prompt closes within a tick.
4. A member who accepts sends `RecallScroll` (recv `0x70`):
   `byte slot` (echoed from the prompt), `ustring caster name`, `int map id`.
   Declining or letting the prompt expire sends nothing. On accept the
   server validates the prompt against party state (slot, caster name,
   member still targeted, caster still a live party member) and then pulls
   that member to the caster's current map/position/instance, replying
   `RecallScroll` mode `0` (`byte slot`) to close the prompt.
5. The window is server-chosen (60s). On expiry the server sends mode `0` to
   every member still holding a prompt. If the caster leaves the party or
   logs out first, mode `0` closes everyone's prompt. Members who leave, are
   kicked, or go offline are pruned from the prompts; an emptied recall is
   cleared outright.

State lives on the party (`PartyServer`'s `recall` field: the caster's id
and name, the pending targets' session pids, a window timer). No character
structs are stored: prompt targets are resolved live by the caster's session
before the recall starts, accepts are validated against party state, and the
party manager never calls into the character managers, keeping its callbacks
free of cross-process calls that could deadlock.

## Open gaps

- The `RecallUser` flow (single-user summon request with a modal yes/no box,
  recv `0x8E` / send `0x5E`) is not implemented; it is a separate opcode
  family from the scroll recall.
- Guild and wedding recalls share the prompt type space (type 1 and 2) but
  only the party path exists.
- Maps can forbid recall; the server does not check a map property for this
  (the client disables its own button, but the server trusts the request).
