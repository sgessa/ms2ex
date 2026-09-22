# `Ms2ex.Managers.Field.BattleStance`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/battle_stance.ex#L1)

The player battle stance (weapon drawn) and its quiet-window expiry. The
client renders a player's weapon in hand only while the player is in the
battle state, which the server signals with the UserBattle packet on every
stance change (see `Packets.UserBattle`).

The field owns one deadline per character (`:battle_stances`): every
in-battle cast re-stamps it, the stance holds through continuous combat,
and it drops once a window passes without a cast.

# `arm`

Arms (or re-stamps) the character's battle-stance deadline. Every
in-battle cast re-stamps it, so the stance holds through continuous
combat and only drops after a quiet window since the last cast.

# `drop`

Drops the battle stance once the character's quiet window has passed:
stays scheduled while casts keep the deadline in the future, leaves
(broadcasting the sheathe) once the window closed.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
