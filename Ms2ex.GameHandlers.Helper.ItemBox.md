# `Ms2ex.GameHandlers.Helper.ItemBox`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/handlers/game/helpers/item_box.ex#L1)

Item box opening: resolves the box's function parameters against the
server drop tables, rolls the contents for the opening character, grants
them, and consumes the box (plus any key items) per open.

Mirrors the reference ItemBoxManager: OpenItemBox (drop tables plus an
optional direct item), SelectItemBox (player picks an entry by index
from one drop group) and OpenItemBoxWithKey (consumes key items). The
reference mails rewards that do not fit the inventory; there is no mail
system yet, so a failed grant stops the open with the inventory-full
error and leaves the remaining boxes unopened.

# `open`

Opens `count` copies of the box, pushing an `ItemBox.Open` response with
the number of successful opens and the resulting error code.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
