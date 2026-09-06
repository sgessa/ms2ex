# `Ms2ex.GameHandlers.Helper.ItemBox`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/handlers/game/helpers/item_box.ex#L1)

Item box opening: resolves the box's function parameters against the
server drop tables, rolls the contents for the opening character, grants
them, and consumes the box (plus any key items) per open.

Three open flows: OpenItemBox (drop tables plus an optional direct
item), SelectItemBox (player picks an entry by index from one drop
group) and OpenItemBoxWithKey (consumes key items). Rewards that do
not fit the inventory are mailed to the character, stopping
subsequent opens with the inventory-full error.

# `open`

Opens `count` copies of the box, pushing an `ItemBox.Open` response with
the number of successful opens and the resulting error code.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
