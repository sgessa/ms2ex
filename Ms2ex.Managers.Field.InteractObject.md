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

# `tick`

Flips objects whose cooldown elapsed (Normal -> Reactable or Hidden).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
