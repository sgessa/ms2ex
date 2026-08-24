# `Ms2ex.Context.Emotes`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/emotes.ex#L1)

Context module for character emote-related operations.

This module provides functions for listing, learning, and accessing
default emotes available to characters.

# `default_emotes`

```elixir
@spec default_emotes() :: [integer()]
```

Returns the list of default emote IDs available to all characters.

## Examples

    iex> default_emotes()
    [90200011, 90200004, 90200024, 90200041, 90200042]

# `learn`

```elixir
@spec learn(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Emote.t()} | {:error, Ecto.Changeset.t()}
```

Makes a character learn a new emote by ID.

## Examples

    iex> learn(character, 90200011)
    {:ok, %Schema.Emote{}}

    iex> learn(character, 90200011) # when already learned
    {:error, %Ecto.Changeset{}}

# `list`

```elixir
@spec list(Ms2ex.Schema.Character.t()) :: [integer()]
```

Lists all emote IDs that a character has learned.

## Examples

    iex> list(character)
    [90200011, 90200004, 90200024, 90200041, 90200042]

---

*Consult [api-reference.md](api-reference.md) for complete listing*
