# Housing & UGC cube system

Status: open. The cube packet surface is almost entirely unimplemented:
`RequestCube` handles only `remove_cube` (0x0C); every other mode falls into
the unhandled-mode warning.

## Still missing

- hold cube; buy/forfeit/extend plot; place/rotate/replace cube; liftup
  object / liftup drop (0x11 is what the client sends when grabbing a placed
  furnishing); home name / passcode / vote / message; clear cubes; plot area
  and height changes; design rank rewards; permissions; save/load home;
  blueprints; kick out; background / lighting / camera
- plots, furnishings and home ownership have no server model yet
- field-load cube packets send empty data
- layout blueprints depend on this system (the blueprint block written next
  to the UGC descriptor is currently all zeroes — see ugc.md)
- the guild house map's interior content depends on this too (see
  guild-system.md)
