# Currency wallets

Status: complete — wallets enforce the client's currency caps on every
credit, and debits fail wholesale instead of driving balances negative.

## Model

Two wallet tables: `wallets` per character (mesos, valor tokens, trevas,
rues, havi fruits) and `account_wallets` per account (merets, event merets,
game merets, meso tokens). Every mutation goes through `Ms2ex.Context.Wallets`,
which clamps and validates against the caps before writing, then pushes the
wallet packet with the *applied* delta.

## Caps

| currency | cap source |
| --- | --- |
| mesos | unbounded (`MaxMeso` = long max, as the reference) |
| merets / event merets / game merets | unbounded (`MaxMeret`) |
| valor tokens | `HonorTokenMax` (5000) |
| trevas | `KarmaTokenMax` (75000) |
| rues | `LuTokenMax` (2000) |
| havi fruits | `HabiTokenMax` (35000) |
| meso tokens | 100000 (reference constant; the client table has no key) |

The token caps come from the client's server constants table
(`Storage.Tables.Constants`) and are mirrored as DB CHECK constraints
(`token_caps` on `wallets`, `meso_token_cap` on `account_wallets`) alongside
the existing non-negativity checks — a last-resort backstop should any write
path bypass the context; changing a cap means a migration. Reverse coin,
mentor/mentee and star point caps exist in the data but those wallets are
not modeled yet.

## Semantics

- **Credit** (`update/3` with a positive delta): applied up to the cap; the
  excess is reported as `overflow` in the currency-token packet
  (balance, applied delta, int, overflow — the client shows a loss notice).
- **Debit** (`update/3` negative or `debit/3`): fails wholesale with
  `{:error, :insufficient_funds}` when the balance cannot cover it —
  balances never go negative. Purchase flows use `debit/3`; credit-only
  flows use `update/3`.
- **`can_add/3`**: the reference's `CanAddMeso` semantics — how much of an
  amount would actually apply (credits clamp at the cap, debits at zero).
- **`set/3`**: absolute overwrite, clamped into `[0, cap]`.

Debit call sites (guild create/donation, mastery crafting, taxis, smart
push, item boxes, shop payments, storage mesos) all check or match the
result before proceeding.

## Gaps

- The reference fires quest conditions on token gains (`get_honor_token`,
  `get_karma_token`, ...); ms2ex does not model those condition types yet.
- Reverse coin, mentor/mentee and star point wallets are unmodeled (see the
  shops doc for how shop entries priced in them behave).
