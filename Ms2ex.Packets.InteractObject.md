# `Ms2ex.Packets.InteractObject`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/packets/game/interact_object.ex#L1)

Interact-object frames: field objects the client renders and lets players
interact with (weeds, telescopes, gathering nodes, ...).

# `add`

Announces a dynamically spawned object (ad balloon, treasure chest) with its
full rendering data.

# `interact`

Plays the interaction animation for an object on every client. Gathering
nodes additionally carry whether the harvest succeeded and how much of the
node it consumed.

# `load`

Announces the field's interact objects to a joining player. The client only
enables interaction tooltips for objects announced through this frame.

# `result`

Notice the client shows once an interaction resolved.

# `update`

Broadcasts an object's state change (normal / reactable / hidden).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
