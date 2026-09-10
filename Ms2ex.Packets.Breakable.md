# `Ms2ex.Packets.Breakable`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/packets/game/breakable.ex#L1)

# `load`

Announces the field's breakable objects to a joining player. Breakables
toggle between shown/hidden/broken states as trigger scripts drive them.

# `load_empty`

# `update`

Applies a state/visible change to a batch of breakable objects. Each entry
carries the map entity uuid the client knows the object by, plus its state
byte and visibility.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
