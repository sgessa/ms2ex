# `Ms2ex.Context.Accounts`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/accounts.ex#L1)

Context module for account-related operations.

This module provides functions for authentication, creation, retrieval,
updating, and deletion of user accounts.

# `authenticate`

```elixir
@spec authenticate(String.t(), String.t()) ::
  {:ok, Ms2ex.Schema.Account.t()} | {:error, :invalid_credentials}
```

Authenticates a user with a username and password.

Returns `{:ok, account}` if authentication is successful,
or `{:error, :invalid_credentials}` if username doesn't exist or password is incorrect.

## Examples

    iex> authenticate("username", "password")
    {:ok, %Schema.Account{}}

    iex> authenticate("wrong_username", "password")
    {:error, :invalid_credentials}

# `create`

```elixir
@spec create(map()) :: {:ok, Ms2ex.Schema.Account.t()} | {:error, Ecto.Changeset.t()}
```

Creates a new account with the given attributes.

## Examples

    iex> create(%{username: "new_user", password: "secret"})
    {:ok, %Schema.Account{}}

    iex> create(%{username: "", password: ""})
    {:error, %Ecto.Changeset{}}

# `delete`

```elixir
@spec delete(Ms2ex.Schema.Account.t()) ::
  {:ok, Ms2ex.Schema.Account.t()} | {:error, Ecto.Changeset.t()}
```

Deletes an account.

## Examples

    iex> delete(account)
    {:ok, %Schema.Account{}}

# `get`

```elixir
@spec get(integer()) :: Ms2ex.Schema.Account.t() | nil
```

Gets an account by ID.

Returns the account if found, or `nil` if not found.

## Examples

    iex> get(1)
    %Schema.Account{}

    iex> get(999)
    nil

# `update`

```elixir
@spec update(Ms2ex.Schema.Account.t(), map()) ::
  {:ok, Ms2ex.Schema.Account.t()} | {:error, Ecto.Changeset.t()}
```

Updates an account with the given attributes.

## Examples

    iex> update(account, %{username: "updated_name"})
    {:ok, %Schema.Account{}}

    iex> update(account, %{username: ""})
    {:error, %Ecto.Changeset{}}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
