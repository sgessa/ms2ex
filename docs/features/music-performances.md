# Music performances

Status: instruments are field objects owned by the performer: improvising
relays midi notes to the map, scores play from their metadata file name or a
composed MML string, composing writes the score onto the item, and plays are
debited from the score's remaining uses. Party ensembles start every ready
member on the leader's tick. The Queenstown stage tracks one performer at a
time behind the `music_concert` field property, and Smart Push grants the
paid additional effects (auto-play extension, mount stability).

## Still missing

- fishing lures: bait tags, `fishlure.xml`, lure catch ranks and lure fish
  spawns are projected and used, but the client bait-slot amount does not
  refresh from the inventory packet; the dedicated bait-slot/autobait packet
  still needs client reversing (see fishing-bait.md)
- stage geometry: enter/exit stage toggles between portals 802 and 803 from
  a server-side membership set; it should decide from trigger box 101
  containment, which needs trigger box geometry in the map projection
- performance stage extras: the applaud and glowstick emotes (skills
  90210001 / 90210002) are parsed and dropped, and party members of the
  performer are not treated as co-performers
- Smart Push gaps: the `SaleAutoFishing` / `SaleAutoPlayInstrument`
  game-event content override is skipped. Two deliberate divergences: an
  unaffordable purchase answers with the lack-of-currency notice, and
  entering water without the `SafeWaterRiding` effect throws the rider
  server-side instead of leaving the dismount to the client
- score expiry: expired scores should be refused (only remaining uses are
  checked)
- ensemble room check: members are matched on map and channel; the
  instanced-room id comparison is missing
