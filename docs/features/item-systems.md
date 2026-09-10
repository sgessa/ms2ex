# Item systems: gem sockets, pet items, gacha

Status: open. The item packet writes inert defaults for three systems the
server does not implement, so every item serializes as if it had none:

- gacha dismantle id (always 0)
- pet info block (never written)
- gemstone sockets (empty socket block only; socket unlocking and gemstones
  are unimplemented)

Implementing any of these needs the feature system plus, for pets, ingest
projection of pet metadata.
