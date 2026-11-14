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
2. The server consumes/buys the scroll in the caster's inventory, then sends
   `RecallScroll` (send `0xBE`) mode `1` to every eligible member: online,
   alive, in a field, and not already on the caster's field. Layout:
   `byte type` (0 party, 1 guild, 2 wedding), `ustring caster name`,
   `int` (stored, unused), `int map id`, `int` (stored, unused), `long
   deadline` — a server-tick timestamp (same clock as the time sync). The
   client shows a bottom-centre prompt with a countdown that turns red in
   the last ten seconds.
3. A member who accepts sends `RecallScroll` (recv `0x70`):
   `byte type`, `ustring caster name`, `int map id`. Declining or letting the
   prompt expire sends nothing. On accept the server pulls that member to the
   caster's current map/position/instance and replies `RecallScroll` mode `0`
   (`byte type`) to close the prompt.
4. The window is server-chosen (60s). On expiry the server sends mode `0` to
   every member still holding a prompt. If the caster leaves the party or
   logs out first, mode `0` closes everyone's prompt.

State lives on the party (`PartyServer`'s `recall` field: caster, pending
targets, window timer). The caster must still be a live party member when a
prompt is accepted; stale or forged accepts are dropped.

## Open gaps

- The `RecallUser` flow (single-user summon request with a modal yes/no box,
  recv `0x8C` / send `0x5D`) is not implemented; it is a separate opcode
  family from the scroll recall.
- Guild and wedding recalls share the prompt type space (type 1 and 2) but
  only the party path exists.
- Maps can forbid recall; the server does not check a map property for this
  (the client disables its own button, but the server trusts the request).
