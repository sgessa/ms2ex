# `Ms2ex.Context.Friends`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/friends.ex#L1)

Context module for friend-related operations.

This module provides functions for managing friend relationships between characters.

# `block`

```elixir
@spec block(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Character.t(), String.t()) ::
  {:ok, Ms2ex.Schema.Friend.t()} | {:error, Ecto.Changeset.t()}
```

Blocks another character.

Creates a new friend record with a blocked status.

## Examples

    iex> block(character, blocked_character, "Spam")
    {:ok, %Schema.Friend{status: :blocked}}

# `block_friend`

```elixir
@spec block_friend(Ms2ex.Schema.Friend.t(), Ms2ex.Schema.Friend.t(), String.t()) ::
  {:ok, {Ms2ex.Schema.Friend.t(), Ms2ex.Schema.Friend.t()}}
  | {:error, Ecto.Changeset.t()}
```

Blocks an existing friend.

Updates the source friend record to blocked status and deletes the destination record.

## Examples

    iex> block_friend(src_friend, dst_friend, "Spam")
    {:ok, {%Schema.Friend{status: :blocked}, %Schema.Friend{}}}

# `delete`

```elixir
@spec delete(Ms2ex.Schema.Friend.t()) ::
  {:ok, Ms2ex.Schema.Friend.t()} | {:error, Ecto.Changeset.t()}
```

Deletes a friend record.

## Examples

    iex> delete(friend)
    {:ok, %Schema.Friend{}}

# `delete_all`

```elixir
@spec delete_all(String.t()) :: {non_neg_integer(), nil | [term()]}
```

Deletes all friend records with a given shared ID.

## Examples

    iex> delete_all("shared123")
    {2, nil}

# `get_by_character_and_shared_id`

```elixir
@spec get_by_character_and_shared_id(integer(), String.t(), boolean()) ::
  Ms2ex.Schema.Friend.t() | nil
```

Gets a friend relationship by character ID and shared relationship ID.

## Parameters

  * `char_id` - The character ID
  * `shared_id` - The shared relationship ID
  * `preload_rcpt?` - Whether to preload the recipient association (default: false)

## Examples

    iex> get_by_character_and_shared_id(1, "shared123")
    %Schema.Friend{}

    iex> get_by_character_and_shared_id(1, "nonexistent")
    nil

# `send_request`

```elixir
@spec send_request(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Character.t(), String.t()) ::
  {:ok, {Ms2ex.Schema.Friend.t(), Ms2ex.Schema.Friend.t()}}
  | {:error, Ecto.Changeset.t()}
```

Sends a friend request from one character to another.

Creates two friend records with a shared ID - one for the sender and one for the recipient.

## Examples

    iex> send_request(character, friend, "Let's be friends!")
    {:ok, {%Schema.Friend{}, %Schema.Friend{}}}

# `subscribe`

```elixir
@spec subscribe(Ms2ex.Schema.Character.t(), integer()) :: :ok
```

Subscribes a character to presence updates for another character.

## Examples

    iex> subscribe(character, friend_id)
    :ok

# `unsubscribe`

```elixir
@spec unsubscribe(Ms2ex.Schema.Character.t(), integer()) :: :ok
```

Unsubscribes a character from presence updates for another character.

## Examples

    iex> unsubscribe(character, friend_id)
    :ok

# `update`

```elixir
@spec update(Ms2ex.Schema.Friend.t(), map()) ::
  {:ok, Ms2ex.Schema.Friend.t()} | {:error, Ecto.Changeset.t()}
```

Updates a friend record with the given attributes.

## Examples

    iex> update(friend, %{status: :accepted})
    {:ok, %Schema.Friend{status: :accepted}}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
