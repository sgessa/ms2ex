# `Ms2ex.Managers.Character.Fishing`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character/fishing.ex#L1)

Fishing state owned by the character process: the active rod, the water
tiles it reaches, the fish currently biting and the fish album.

The album is persisted alongside the mastery state on the periodic flush.

# `album`

Fish album, keyed by fish id.

# `bite`

Stores which tile is being fished and which fish is biting.

# `clear_minigame`

# `move_guide`

Tracks where the player dragged the bobber.

# `record_catch`

Records a catch in the album. Returns the updated character, the album
entry and whether this was the first catch of that kind.

# `select_bait`

# `session`

The active fishing session, or nil when the player is not fishing.

# `start_session`

# `stop_session`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
