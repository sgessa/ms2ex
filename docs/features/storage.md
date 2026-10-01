# Bank storage

Status: the full storage loop is live — opening a storage npc starts the
per-account storage process, and deposit/withdraw/move/mesos/expand/sort/
delete all work against the shared account inventory.

## Model

Storage is per **account**: stored mesos and the slot expansion live in
`account_storages` (one row per account), and stored items are
`inventory_items` rows owned by the account (`character_id` nil,
`account_id` set) — invisible to every character-scoped inventory query.
The slot array is flat: `base_storage_count` (36) plus 6 slots per
expansion, capped by the client's `store_expand_max_slot_count` (168).

## Lifecycle

The storage process (`Ms2ex.Managers.Storage`, `storages:<account_id>`) is
lazy: the client's `RequestItemStorage` load command (12) starts it and
pushes the window contents; the close command (15) stops it. Every mutation
persists immediately. Because the process is account-keyed, two characters
of the same account share one storage.

Talking to a storage npc (`basic.kind == 2`) answers the talk with the
dialog flag (see the kind routing in `docs/features/shops.md`'s npc talk
section); the client then opens the storage window and sends the load
request itself.

## Packets

`Packets.StorageInventory` (send op `STORAGE_INVENTORY`, recv op
`REQUEST_ITEM_STORAGE`): reset (0xB), slots_expanded (0xD), update_mesos
(0x3), slots_used (0x4), load/reload batches of 10 items (0x5/0x8), add
(0x0), remove (0x1), move (0x2), update (0x9) and error (0x10,
`Enums.StorageError`). Requests: deposit (0), withdraw (1), move (2), mesos
deposit/withdraw (3), expand (6), sort (8), delete (10), load (12), close
(15).

## Flows

- **Deposit**: inventory item (or part of a stack) is consumed from the
  inventory (client gets the inventory consume packet) and stored. The
  requested slot wins when free, otherwise the item stacks onto same
  item/rarity stacks, the remainder goes to the first open slot. A full
  storage with no stack room errors `store_full`; when slots are full but
  stacks have room, only the stackable part is stored.
- **Withdraw**: the storage refuses to hand a character-bound item to a
  different character of the account once bind owners are tracked. The
  inventory space is checked before removing from storage, so a full
  inventory can never lose the item. Part of a stack leaves the remainder
  stored; the withdrawn portion lands in the slot the user picked in the UI
  (the inventory add honors an explicitly requested free slot).
- **Move**: swaps the source with whatever occupies the target slot and
  echoes the move packet.
- **Mesos**: deposit debits the wallet (failing with the storage error when
  the balance cannot cover it), withdraw credits it; both write through to
  `account_storages` and push `update_mesos`. Wallet caps are the wallet
  context's business (see `currency-wallets.md`).
- **Expand**: one row (6 slots) per purchase for the configured
  `storage_expand_price1_row` merets (`config :ms2ex, :constants`), capped at
  the client's `store_expand_max_slot_count` (168), then the window is
  re-sent. The price is a server constant because the client's server table
  only carries region-tagged values (KR 100 / CN 1500) that the parser
  filters out; the NA client charges its built-in price (330).
- **Sort**: compacts the rows ordered by item id, rarity, amount and re-sends
  the full window (reset + slots + mesos + used + load batches) — the load
  sequence is what the client re-renders; its reload command never redraws
  the window.
- **Delete**: destroys the stored item (no inventory re-add).

## Gaps

- Character-bound items can be withdrawn by any character of the account:
  the bind flag persists but the binding character does not yet, so the
  `binditem_store_out` check is pending (see the withdraw flow above).
- Withdrawing special item types: currency items are credited to the wallet,
  medals go to survival and furnishings to furnishing storage when they
  leave storage; ms2ex hands them back as ordinary inventory items.
- Expansion pricing is a server config constant (330, the client's built-in
  price); the client's server table only carries region-tagged values
  (KR 100 / CN 1500).
- Beauty (kind 30–39), black market (86), birthday (88) and roulette (501)
  npcs share the dialog routing but have no server systems yet.
- The `OpenDialog` storage packet is unused (the client opens the window
  from the npc-talk dialog response).
