# `Ms2ex.Context.Mails`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/mails.ex#L1)

Context module for the Mail System: mail rows, attachments and their
read/collected timestamps. Sending and collection flows live in
`Ms2ex.Managers.Mail`.

# `attach_items_to_mail`

Attaches item rows to a mail (moved out of the character's inventory).

# `bind_account_mails`

```elixir
@spec bind_account_mails(integer(), integer()) :: {integer(), nil | [term()]}
```

Binds all account-level mails to the given character.

# `bulk_delete`

```elixir
@spec bulk_delete([integer()], integer()) :: {:ok, [integer()]}
```

Bulk deletes multiple mails that are eligible for deletion.

# `bulk_read`

```elixir
@spec bulk_read([integer()], Ms2ex.Schema.Character.t()) ::
  {:ok, [Ms2ex.Schema.Mail.t()]}
```

Bulk marks multiple mails as read.

# `count_unread`

```elixir
@spec count_unread(integer()) :: non_neg_integer()
```

Counts unread non-expired mails for a character.

# `delete`

```elixir
@spec delete(integer(), integer()) :: {:ok, integer()} | {:error, atom()}
```

Deletes a mail if it has no uncollected attachments.

# `delete_item`

Deletes a detached attachment item row after it moved to the inventory.

# `get`

```elixir
@spec get(integer(), integer()) :: Ms2ex.Schema.Mail.t() | nil
```

Gets a single mail by ID for a character.

# `insert_player_mail`

```elixir
@spec insert_player_mail(
  Ms2ex.Schema.Character.t(),
  Ms2ex.Schema.Character.t(),
  String.t(),
  String.t()
) ::
  {:ok, Ms2ex.Schema.Mail.t()} | {:error, atom()}
```

Inserts a player-to-player mail row.

# `insert_system_mail`

```elixir
@spec insert_system_mail(map()) :: {:ok, Ms2ex.Schema.Mail.t()} | {:error, term()}
```

Inserts a system mail row.

# `list`

```elixir
@spec list(integer(), integer() | nil) :: [Ms2ex.Schema.Mail.t()]
```

Lists all non-expired mails for a character, preloading their items.

# `mark_collected`

Marks a mail's attachments as collected.

# `read`

```elixir
@spec read(integer(), Ms2ex.Schema.Character.t()) ::
  {:ok, Ms2ex.Schema.Mail.t()} | {:error, atom()}
```

Marks a mail as read.

# `validate_collectible`

Whether a mail can still be collected (not expired, attachments pending).
Returns `:ok` or `{:error, code}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
