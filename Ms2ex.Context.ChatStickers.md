# `Ms2ex.Context.ChatStickers`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/chat_stickers.ex#L1)

Context module for managing chat stickers.

# `add`

```elixir
@spec add(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.ChatStickerGroup.t()} | {:error, Ecto.Changeset.t()}
```

Adds a sticker group to a character.

## Examples

    iex> add(character, 1)
    {:ok, %Schema.ChatStickerGroup{}}

    iex> add(character, 1) # when already exists
    {:error, %Ecto.Changeset{}}

# `default_stickers`

```elixir
@spec default_stickers() :: Range.t()
```

Returns the list of default sticker IDs available to all characters.

## Examples

    iex> default_stickers()
    1..3

# `favorite`

```elixir
@spec favorite(Ms2ex.Schema.Character.t(), integer(), integer()) ::
  {:ok, Ms2ex.Schema.FavoriteChatSticker.t()} | {:error, Ecto.Changeset.t()}
```

Marks a sticker as favorite for a character.

## Examples

    iex> favorite(character, 101, 1)
    {:ok, %Schema.FavoriteChatSticker{}}

# `get`

```elixir
@spec get(Ms2ex.Schema.Character.t(), integer()) ::
  Ms2ex.Schema.ChatStickerGroup.t() | nil
```

Gets a specific sticker group for a character by group ID.

Returns the chat sticker group if found, otherwise nil.

## Examples

    iex> get(character, 1)
    %Schema.ChatStickerGroup{}

    iex> get(character, 999)
    nil

# `list_favorited`

```elixir
@spec list_favorited(Ms2ex.Schema.Character.t()) :: [integer()]
```

Lists all favorited stickers for a character.

Returns a list of sticker IDs.

## Examples

    iex> list_favorited(character)
    [101, 102, 103]

# `list_groups`

```elixir
@spec list_groups(Ms2ex.Schema.Character.t()) :: [integer()]
```

Lists all sticker groups for a given character.

Returns a list of group IDs.

## Examples

    iex> list_groups(character)
    [1, 2, 3]

# `unfavorite`

```elixir
@spec unfavorite(Ms2ex.Schema.Character.t(), integer()) ::
  {non_neg_integer(), nil | [term()]}
```

Removes a sticker from a character's favorites.

## Examples

    iex> unfavorite(character, 101)
    {1, nil}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
