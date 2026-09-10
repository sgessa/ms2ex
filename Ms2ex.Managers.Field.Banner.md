# `Ms2ex.Managers.Field.Banner`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/banner.ex#L1)

UGC banners: each map's banners own a set of slots players reserve and
attach artwork to. Slots are either hour-scoped (a fixed hour of the day)
or event-scoped (an explicit start/end time). Slot documents persist
through `Context.BannerSlots`; the field keeps the live copy, activates
slots as their windows open and broadcasts the transitions.

# `activate`

Refreshes slot activity against the clock: expired event slots are
dropped (and deleted), hour slots flip active/inactive. Returns
`{state, changed_banners}` — only banners whose slot set changed.

# `all`

Every banner of the field with its live slot set.

# `attach`

Attaches artwork to the character's own empty slots. Every requested slot
must be attachable; the attachment persists only when they all are.

# `confirm`

Confirms the upload behind an artwork resource: the slot carrying that
resource receives the rendered image path.

# `load`

Loads every banner of the map with its persisted slots.

# `reserve`

Reserves slots for a character; the reservation persists immediately.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
