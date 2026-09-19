# `Ms2ex.Managers.Field.InteractObject`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/interact_object.ex#L1)

Interact-object lifecycle: objects start Normal, become Reactable on the
first tick, and flip back to Normal when a player interacts. Exhausted
objects (react count reached) hide permanently, unless a hide delay is
configured. Normal objects return to Reactable after their reset time.

# `load`

# `react`

Completes an interaction with an object. Only Reactable objects can be
interacted with; the animation goes to the interacting player while the
state transition is broadcast to the whole field.

Gathering nodes get no animation here: the harvest decides success first
and sends the animation with its result.

# `set_state`

Script-driven state change (set_interact_object): flips matching objects to
the wanted state and broadcasts each actual change. Objects already in the
state are left untouched so a re-arming cycle does not spam clients, and no
reset timer is touched — the scripted state stands until a player reacts or
another script changes it.

# `tick`

Flips objects whose cooldown elapsed (Normal -> Reactable or Hidden).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
