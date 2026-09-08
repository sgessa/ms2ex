# `Ms2ex.Context.Guilds`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/guilds.ex#L1)

Database context for the Guild System.

# `add_member`

```elixir
@spec add_member(integer(), integer(), integer()) ::
  {:ok, Ms2ex.Schema.GuildMember.t()} | {:error, atom() | Ecto.Changeset.t()}
```

Adds a character as a member to a guild.

# `create`

```elixir
@spec create(Ms2ex.Schema.Character.t(), String.t(), keyword()) ::
  {:ok, Ms2ex.Schema.Guild.t()} | {:error, atom() | Ecto.Changeset.t()}
```

Creates a new guild with the given leader character as Master (rank 0).

# `create_application`

```elixir
@spec create_application(integer(), integer(), integer()) ::
  {:ok, Ms2ex.Schema.GuildApplication.t()} | {:error, atom()}
```

Creates an application to join a guild.

# `delete`

```elixir
@spec delete(integer()) :: {:ok, integer()} | {:error, atom()}
```

Disbands a guild.

# `delete_all_applications_for_character`

```elixir
@spec delete_all_applications_for_character(integer()) :: :ok
```

Deletes all applications from a character across all guilds.

# `delete_application`

```elixir
@spec delete_application(integer()) :: {:ok, integer()} | {:error, atom()}
```

Deletes an application by ID.

# `delete_application_for_character`

```elixir
@spec delete_application_for_character(integer(), integer()) :: :ok
```

Deletes an application for a character in a guild.

# `get`

```elixir
@spec get(integer()) :: Ms2ex.Schema.Guild.t() | nil
```

Gets a guild by ID, preloading members, leader, and applications.

# `get_by_character_id`

```elixir
@spec get_by_character_id(integer()) :: Ms2ex.Schema.Guild.t() | nil
```

Finds the guild that a character belongs to.

# `get_by_name`

```elixir
@spec get_by_name(String.t()) :: Ms2ex.Schema.Guild.t() | nil
```

Gets a guild by its name.

# `list_applications`

```elixir
@spec list_applications(integer()) :: [Ms2ex.Schema.GuildApplication.t()]
```

Lists applications for a guild.

# `list_character_applications`

```elixir
@spec list_character_applications(integer()) :: [Ms2ex.Schema.GuildApplication.t()]
```

Lists applied guilds for a character.

# `remove_member`

```elixir
@spec remove_member(integer(), integer()) :: {:ok, integer()} | {:error, atom()}
```

Removes a member from a guild.

# `search_guilds`

```elixir
@spec search_guilds(atom() | integer(), integer(), integer()) :: [
  Ms2ex.Schema.Guild.t()
]
```

Searches guilds by focus.

# `search_guilds_by_name`

```elixir
@spec search_guilds_by_name(String.t(), integer(), integer()) :: [
  Ms2ex.Schema.Guild.t()
]
```

Searches guilds by name prefix/substring.

# `update_guild`

```elixir
@spec update_guild(Ms2ex.Schema.Guild.t() | integer(), map()) ::
  {:ok, Ms2ex.Schema.Guild.t()} | {:error, atom() | Ecto.Changeset.t()}
```

Updates guild attributes.

# `update_member`

```elixir
@spec update_member(integer(), integer(), map()) ::
  {:ok, Ms2ex.Schema.GuildMember.t()} | {:error, atom() | Ecto.Changeset.t()}
```

Updates a guild member record (rank, message, contributions, checkin/donation timestamps).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
