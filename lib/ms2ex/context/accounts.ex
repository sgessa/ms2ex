defmodule Ms2ex.Context.Accounts do
  @moduledoc """
  Context module for account-related operations.

  This module provides functions for authentication, creation, retrieval,
  updating, and deletion of user accounts.
  """

  alias Ms2ex.{Repo, Schema}

  @doc """
  Authenticates a user with a username and password.

  Returns `{:ok, account}` if authentication is successful,
  or `{:error, :invalid_credentials}` if username doesn't exist or password is incorrect.

  ## Examples

      iex> authenticate("username", "password")
      {:ok, %Schema.Account{}}

      iex> authenticate("wrong_username", "password")
      {:error, :invalid_credentials}
  """
  @spec authenticate(String.t(), String.t()) ::
          {:ok, Schema.Account.t()}
          | {:error, :invalid_credentials}
  def authenticate(username, password) do
    account = Repo.get_by(Schema.Account, username: username)

    case account do
      nil -> {:error, :invalid_credentials}
      _ -> check_password(account, password)
    end
  end

  @spec check_password(Schema.Account.t(), String.t()) ::
          {:ok, Schema.Account.t()}
          | {:error, :invalid_credentials}
  defp check_password(%Schema.Account{password_hash: hash} = account, pwd) do
    case Bcrypt.verify_pass(pwd, hash) do
      true -> {:ok, account}
      false -> {:error, :invalid_credentials}
    end
  end

  @doc """
  Gets an account by ID.

  Returns the account if found, or `nil` if not found.

  ## Examples

      iex> get(1)
      %Schema.Account{}

      iex> get(999)
      nil
  """
  @spec get(integer()) :: Schema.Account.t() | nil
  def get(id), do: Repo.get(Schema.Account, id)

  @doc """
  Creates a new account with the given attributes.

  ## Examples

      iex> create(%{username: "new_user", password: "secret"})
      {:ok, %Schema.Account{}}

      iex> create(%{username: "", password: ""})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(map()) :: {:ok, Schema.Account.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs = Schema.Account.set_default_assocs(attrs)

    %Schema.Account{}
    |> Schema.Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an account with the given attributes.

  ## Examples

      iex> update(account, %{username: "updated_name"})
      {:ok, %Schema.Account{}}

      iex> update(account, %{username: ""})
      {:error, %Ecto.Changeset{}}
  """
  @spec update(Schema.Account.t(), map()) ::
          {:ok, Schema.Account.t()}
          | {:error, Ecto.Changeset.t()}
  def update(%Schema.Account{} = account, attrs) do
    account
    |> Schema.Account.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an account.

  ## Examples

      iex> delete(account)
      {:ok, %Schema.Account{}}
  """
  @spec delete(Schema.Account.t()) ::
          {:ok, Schema.Account.t()}
          | {:error, Ecto.Changeset.t()}
  def delete(%Schema.Account{} = account) do
    Repo.delete(account)
  end
end
