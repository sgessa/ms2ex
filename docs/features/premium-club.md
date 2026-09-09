# Premium Club

Status: implemented — the Premium Club packet flow, metadata projection,
membership persistence, claimed daily benefits, package purchases,
bonus-item delivery, login activation, Premium Club buffs, daily
claimed-item reset, and free meso taxi travel.

## Still missing

- VIP-only dungeon entry checks and the corresponding failure response; the
  dungeon-limit subsystem does not currently expose the `VipOnly` gate
- the Black Market seller tax discount for Premium Club sellers
- package and daily-benefit regression tests: unknown or unavailable
  metadata, sales windows, duplicate claims, full inventory, mail fallback,
  insufficient Merets, concurrent purchases, membership renewal after
  expiry, and packet payloads
