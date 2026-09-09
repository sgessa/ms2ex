# `Ms2ex.Context.Mails`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/mails.ex#L1)

Context module for the Mail System.
Manages player-to-player mail, system mail, attachments, and collection.

# `bind_account_mails`

```elixir
@spec bind_account_mails(integer(), integer()) :: {integer(), nil | [term()]}
```

Binds all account-level mails to the given character.

# `bulk_collect`

```elixir
@spec bulk_collect([integer()], Ms2ex.Schema.Character.t()) ::
  {:ok, [Ms2ex.Schema.Mail.t()]}
```

Bulk collects attachments from multiple mails.

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

# `collect`

```elixir
@spec collect(integer(), Ms2ex.Schema.Character.t()) ::
  {:ok, Ms2ex.Schema.Mail.t()} | {:error, atom()}
```

Collects attachments (currencies and items) from a mail.

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

# `get`

```elixir
@spec get(integer(), integer()) :: Ms2ex.Schema.Mail.t() | nil
```

Gets a single mail by ID for a character.

# `list`

```elixir
@spec list(integer(), integer() | nil) :: [Ms2ex.Schema.Mail.t()]
```

Lists all non-expired mails for a character, preloading their items.

# `notify_recipient`

```elixir
@spec notify_recipient(integer(), boolean()) :: :ok
```

Pushes an unread mail notification to an online character.

# `read`

```elixir
@spec read(integer(), Ms2ex.Schema.Character.t()) ::
  {:ok, Ms2ex.Schema.Mail.t()} | {:error, atom()}
```

Marks a mail as read.

# `send_player_mail`

```elixir
@spec send_player_mail(Ms2ex.Schema.Character.t(), String.t(), String.t(), String.t()) ::
  {:ok, Ms2ex.Schema.Mail.t()} | {:error, atom()}
```

Sends a player-to-player mail.

# `send_system_mail`

```elixir
@spec send_system_mail(integer(), String.t(), atom() | String.t(), keyword()) ::
  {:ok, Ms2ex.Schema.Mail.t()} | {:error, atom()}
```

Sends a system mail with optional currency and item attachments.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
