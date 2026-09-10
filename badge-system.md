# Badge system

Status: implemented — badge items have type classification and payload
serialization. Equipped non-pet badges can be equipped, replaced by type,
unequipped, edited for transparency, persisted through the inventory
manager, and broadcast with the `BADGE_EQUIP` packet.
Character-list, character-info, and field-player payloads include equipped
badges separately from gear and outfit items. Focused badge type
classification regression tests are in place.

## Still missing

- pet-skin badge behavior and pet model updates (the pet subsystem is not
  implemented)
- buddy pairing effects: buddy badges need runtime couple info (partner
  character id, name, creator flag) written after a couple-effect flow
  succeeds — needs a marriage/couple flow plus persisted item data
- packet-level, replacement, transparency-persistence, and relog integration
  tests (the pure badge id/type regression coverage exists)
- fishing, auto-gather, damage, tombstone, swim-tube, chat-bubble, and
  effect badges
