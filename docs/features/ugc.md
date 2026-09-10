# UGC (user generated content) — investigation notes

Scope: PR #101 (`feat/ugc`). Game/login TCP handlers, UGC send packets, and the
Phoenix web surface under `/ugc`. The notes below call out where the
implementation is intentionally stricter or looser than the client requires.

## Packet layouts (verified)

### Recv 0x39 UGC — game session

- `Upload (0x01)`: long (unknown), info, long (unknown), int, short, short.
  Then per type:
  - item/furniture/mount: long item uid, int item id, int amount, ustring
    name, byte, long cost, bool use-voucher.
  - banner: long banner id, byte hour count, then per hour a reservation
    struct. **Not parsed yet** — TODO.
  - guild banner: long guild id, int banner id. Guild emblem: nothing.
  - layout blueprint: long blueprint uid, long item uid, int item id,
    ustring name. **Not handled** — TODO.
- `Confirmation (0x03)`: info, int, long resource id, ustring file name,
  short. The client also validates account id and rejects id 0 (matched now).
- `ProfilePicture (0x0B)`: ustring path. Broadcasts to the field. The client
  also fires a `change_profile` quest condition — ms2ex condition types don't
  include it yet.
- `LoadBanners (0x12)`, `ReserveBanner (0x13)`: stubbed (empty list / warn).

`UgcInfo` = byte type, byte, byte, int, long account, long character (23 bytes).

### Send 0x6D UGC

- `Upload (0x02)`: type enum (byte), long id, ustring id-as-string.
- `UpdatePath (0x04)`: type, long id, ustring path.
- `ProfilePicture (0x0B)`: int object id (0 on login), long character id,
  ustring path.
- `UpdateItem (0x0D)/Furnishing (0x0E)/Mount (0x0F)`: int object id, long uid,
  int item id, int amount, ustring name, byte 1, long create price, byte 0,
  ugc look.
- `UpdateLayoutBlueprint (0x10)`: int object id, long blueprint uid, long item
  uid, int item id, ustring name, ugc look. (Builder exists, unused until
  housing lands.)
- `SetEndpoint (0x11)`, `LoadBanner (0x12)`: as before.

`UgcItemLook`: long id, ustring id, ustring name, byte 1, int 1, long account,
long character, ustring author, long created unix, ustring url, byte 0. The
byte/int pair is **hardcoded 1/1** for every descriptor,
including defaults — the ms2ex `put_ugc(nil)` branch now matches (was 0/0).

### Item packet — design items

Items with a non-empty `mesh` or `property.type == 22` carry a UGC descriptor
followed by a blueprint block, in place of pet/music/badge:

    long blueprint uid, int length, int width, int height, long created unix,
    int type, long account id, long character id, ustring character name

**Critical finding:** the blueprint `type` is an int-backed enum in the
client (`Copy = 0`, `Original = 1`, default `Original`), so it serializes as
4 bytes — `Write<T>` uses `Unsafe.SizeOf<T>`, and every int-backed enum in the
wire format is an int (cross-checked: the client sends `ChatType`,
also int-backed, as 4 bytes and ms2ex's `get_int` chat parse is
client-verified). The PR originally wrote `put_byte()` (1 byte), which would
shift the entire remainder of the item packet by 3 bytes. Fixed to
`put_int(1)`.

## Web surface (`/ugc` prefix)

Client resolves every path against the resource root handed in
`SetEndpoint`, so prefixing the whole surface with `/ugc` works as long as the
configured resource url keeps the prefix (runtime.exs does).

- `POST /ugc/urq.aspx` — upload envelope: int unknown, int type, long
  account, long character, long resource id, int id, int, long, then raw file
  bytes. Reply is `text/plain` `0,<path>` on success. Ownership is checked
  against the resource row (no additional validation known); profile avatars skip
  the resource entirely and only keep the newest file.
- Fetch routes: `/data/profiles/avatar/:cid/:file.png`, `/item|itemicon|
  banner/blueprint/guildmark/ms2/01/:id/:file` (+ `guildmark .../banner/`).
  Files live under `data_dir` with the same relative layout.
- `irrq.aspx`/`ruq.aspx` return a well-formed empty zlib payload (the
  400s on unknown ranking types and serves trophy/mentor boards — TODO).

## Open items tracked in ROADMAP #20

Guild attachment, field banners + reservations, layout blueprints, free design
coupons, UGC housing maps, UGC market, ranking/mentor boards.

## Merge state (updated after branch update)

The branch merged master (#102–#104) cleanly (`5acfb251`, base = master tip
`e82574eb`) and resolved `ResponseServerEnter` as a **shared** handler
(`Ms2ex.Handlers.ResponseServerEnter` + a router prefix override), so opcode
0xB2 resolves on both the login and channel sessions. That covers the login
flow the client drives and tolerates the packet arriving on the game
connection. Note: the handler pushes banner list/server list/character list
regardless of session type — harmless if the game session never sees 0xB2.

Re-review findings after the update: the merge itself was fine (kept the
activated `put_template` plus master's pet/gem TODOs, restored the equip
tests), but all code findings from the first review were still open and have
been re-applied to the working tree:

- blueprint type `put_int(1)` (was `put_byte()` — 3-byte stream shift)
- `put_ugc(nil)` writes the hardcoded `1`/`1` descriptor pair
- confirmation validates account id + non-zero resource id
- free-slot pre-check before charging (item built first via `design_item/2`)
- `Enums.UgcType` unknown 4/10/202 entries
- TODOs for `:layout_blueprint` uploads and the lack-of-currency notice
- ROADMAP: single "Recently completed" UGC entry, section renumbered 17 → 20
  (17 was already taken by "Item systems: gem sockets, pet items, gacha")
