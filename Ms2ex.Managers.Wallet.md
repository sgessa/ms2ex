# `Ms2ex.Managers.Wallet`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/wallet.ex#L1)

Per-character wallet state: the character's balances (mesos, valor tokens,
trevas, rues, havi fruits) and a copy of the account balances (merets,
event merets, game merets, meso tokens) it spends.

Credits clamp at the currency's cap and report the overflow; debits fail
wholesale with `{:error, :insufficient_funds}` when the balance cannot
cover them — balances never go negative. Every change persists through
`Ms2ex.Context.Wallets` and pushes the wallet packet with the applied
delta.

The account wallet copy is per character manager: two characters of the
same account online at once each hold their own view, matching the
per-session currency of the official servers.

# `account_wallet`

The account balances of the character's account.

# `call`

# `can_add`

How much of `amount` can actually be applied to the currency: credits
clamp at the cap, debits at zero.

# `cap`

The balance a currency may not exceed (the client's server table values).

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `debit`

Deducts `abs(amount)` from a wallet, failing with
`{:error, :insufficient_funds}` when the balance cannot cover it.

# `earn`

Credits `abs(amount)` to a wallet, clamped at the currency's cap. The
packet reports the applied amount and the overflow a clamp produced.

# `find`

The character's balances.

# `set`

Overwrites a balance, clamping it into `[0, cap]`.

# `start`

# `stop`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
