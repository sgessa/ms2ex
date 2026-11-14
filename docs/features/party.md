# Party

Status: mostly working. Invite/accept/leave/kick, leader promotion, ready
check, vote kick, the party finder, and the party damage meter all work. The
party recall (summon scroll) flow is implemented.

## Recall (party summon)

The party menu's recall button pulls party members to the caster's field.
The client runs a five-second cast at the caster before sending anything, so
the server only ever sees the finished request.

Flow:

1. A party member presses the recall button. The client offers it to every
   member (gated on the map allowing recalls, the member standing normally,
   someone else being online); the server accepts requests from any party
   member, not just the leader. The client consumes a held recall scroll,
   or buys one for the meret price first; either way the server receives
   `Party` (recv `0x2C`) mode `0x1D` with no payload.
2. Before consuming anything the server checks that no recall is pending
   and that at least one member is promptable: online, alive, in a field,
   on a different field than the requester, and still in the party.
3. The server consumes/buys the scroll in the caster's inventory, then sends
   `RecallUser` (send `0x8E`) mode `4` to every promptable member:
   `byte mode` (4), `byte type` (0 for party), `ustring caster name`,
   `int request id`. The client shows a modal box — "{caster} wants to
   summon you to their location" — with accept/decline buttons; it closes
   itself after roughly twenty seconds (a timeout answers decline).
4. A member answers with `RecallUser` (recv `0x5E`) mode `4`:
   `byte mode` (4), `int request id`, `byte accepted` (1/0). Declining or
   letting the box time out sends decline. On accept the server matches the
   request id against the pending request, validates against party state
   (member still targeted, caster still a live party member) and then pulls
   that member to the caster's current map/position/instance. A member who
   opens a second prompt while one is pending auto-replies mode `7`
   (`ustring caster name`, `byte flag`) — the server prunes them from the
   matching pending request's targets.
5. The request stays pending server-side for 25s — a small margin past the
   client box's own ~20s lifetime — so a retry after an unanswered prompt
   is only briefly blocked (recall-in-progress). Expiry retires the
   request silently, and expiry timers are matched to their request, so a
   stale timer never clears a newer one. If the caster leaves the party or
   logs out first, the pending request is dropped. Members who leave, are
   kicked, or go offline are pruned from the targets; an emptied request is
   cleared outright.

State lives on the party (`PartyServer`'s `recall` field: the request id,
the caster's id and name, the pending targets' session pids). No character
structs are stored: prompt targets are resolved live by the caster's session
before the request starts, replies are matched by request id and validated
against party state, and the party manager never calls into the character
managers, keeping its callbacks free of cross-process calls that could
deadlock.

## Open gaps

- The requester hears nothing when a member declines or the box times out;
  the client's requester-side notices (`RecallUser` send modes `0x8E`
  sub-modes 5/6/7) are not sent yet.
- The bottom-centre `RecallScroll` bar family (send `0xBE` / recv `0x70`)
  belongs to the cash recall items (guild/party/wedding call scrolls) and is
  not implemented.
- Maps can forbid recall; the server does not check a map property for this
  (the client disables its own button, but the server trusts the request).
