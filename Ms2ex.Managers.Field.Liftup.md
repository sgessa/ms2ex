# `Ms2ex.Managers.Field.Liftup`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/liftup.ex#L1)

Liftable object weapons (barrels, crates, pots): the player picks one up
with the interact key, the held object replaces the castable skills with
the throw skill granted by the rolled item, and the throw releases it.
The weapon sits back on its tile after its respawn delay, and a hostile
npc may burst out of the container on lift.

# `drop`

The player drops the held object weapon without throwing it: the hold
clears and clients release the carry pose.

# `init_liftups`

# `liftup`

The player lifts the object weapon at a grid tile. One of the weapon's
item ids is rolled (rotating with the shared tick), the item's metadata
grants the throw skill, and the respawn delay is reported to clients so
the container visual returns on time.

Returns `{state, :ok}` or `{state, {:error, code}}` for the error notice.

# `no_cube_to_lift`

# `not_allowed_item`

# `release`

# `use_skill`

Cast gate while holding an object weapon: only the held object's throw
skill casts (and consumes the hold), every other skill is refused.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
