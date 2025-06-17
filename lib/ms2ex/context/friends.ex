defmodule Ms2ex.Context.Friends do
  @moduledoc """
  Context module for friend-related operations.

  This module provides functions for managing friend relationships between characters.
  """

  alias Ms2ex.{Repo, Schema}

  import Ecto.Query

  @doc """
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
  """
  @spec get_by_character_and_shared_id(integer(), String.t(), boolean()) ::
          Schema.Friend.t() | nil
  def get_by_character_and_shared_id(char_id, shared_id, preload_rcpt? \\ false) do
    Schema.Friend
    |> where([f], f.shared_id == ^shared_id and f.rcpt_id != ^char_id)
    |> maybe_preload_rcpt(preload_rcpt?)
    |> limit(1)
    |> Repo.one()
  end

  defp maybe_preload_rcpt(query, true), do: preload(query, [_f], [:rcpt])
  defp maybe_preload_rcpt(query, _), do: query

  @doc """
  Sends a friend request from one character to another.

  Creates two friend records with a shared ID - one for the sender and one for the recipient.

  ## Examples

      iex> send_request(character, friend, "Let's be friends!")
      {:ok, {%Schema.Friend{}, %Schema.Friend{}}}
  """
  @spec send_request(Schema.Character.t(), Schema.Character.t(), String.t()) ::
          {:ok, {Schema.Friend.t(), Schema.Friend.t()}} | {:error, Ecto.Changeset.t()}
  def send_request(%Schema.Character{} = character, %Schema.Character{} = friend, message) do
    shared_id = Ms2ex.generate_id()

    src_attrs = %{message: message, shared_id: shared_id, status: :pending}

    dst_attrs = %{
      is_request: true,
      message: message,
      shared_id: shared_id,
      status: :accepted
    }

    src =
      character
      |> Ecto.build_assoc(:friends)
      |> Schema.Friend.add(friend, src_attrs)

    dst =
      friend
      |> Ecto.build_assoc(:friends)
      |> Schema.Friend.add(character, dst_attrs)

    Repo.transaction(fn ->
      with {:ok, src} <- Repo.insert(src),
           {:ok, dst} <- Repo.insert(dst) do
        {src, dst}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Blocks another character.

  Creates a new friend record with a blocked status.

  ## Examples

      iex> block(character, blocked_character, "Spam")
      {:ok, %Schema.Friend{status: :blocked}}
  """
  @spec block(Schema.Character.t(), Schema.Character.t(), String.t()) ::
          {:ok, Schema.Friend.t()} | {:error, Ecto.Changeset.t()}
  def block(%Schema.Character{} = character, %Schema.Character{} = rcpt, reason) do
    shared_id = Ms2ex.generate_id()
    attrs = %{shared_id: shared_id, block_reason: reason, status: :blocked}

    character
    |> Ecto.build_assoc(:friends)
    |> Schema.Friend.block(rcpt, attrs)
    |> Repo.insert()
  end

  @doc """
  Blocks an existing friend.

  Updates the source friend record to blocked status and deletes the destination record.

  ## Examples

      iex> block_friend(src_friend, dst_friend, "Spam")
      {:ok, {%Schema.Friend{status: :blocked}, %Schema.Friend{}}}
  """
  @spec block_friend(Schema.Friend.t(), Schema.Friend.t(), String.t()) ::
          {:ok, {Schema.Friend.t(), Schema.Friend.t()}} | {:error, Ecto.Changeset.t()}
  def block_friend(src, dst, reason) do
    change = Schema.Friend.block_friend(src, reason)

    Repo.transaction(fn ->
      with {:ok, src} <- Repo.update(change),
           {:ok, dst} <- Repo.delete(dst) do
        {src, dst}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates a friend record with the given attributes.

  ## Examples

      iex> update(friend, %{status: :accepted})
      {:ok, %Schema.Friend{status: :accepted}}
  """
  @spec update(Schema.Friend.t(), map()) ::
          {:ok, Schema.Friend.t()} | {:error, Ecto.Changeset.t()}
  def update(%Schema.Friend{} = friend, attrs) do
    friend
    |> Schema.Friend.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes all friend records with a given shared ID.

  ## Examples

      iex> delete_all("shared123")
      {2, nil}
  """
  @spec delete_all(String.t()) :: {non_neg_integer(), nil | [term()]}
  def delete_all(shared_id) do
    Schema.Friend
    |> where([f], f.shared_id == ^shared_id)
    |> Repo.delete_all()
  end

  @doc """
  Deletes a friend record.

  ## Examples

      iex> delete(friend)
      {:ok, %Schema.Friend{}}
  """
  @spec delete(Schema.Friend.t()) :: {:ok, Schema.Friend.t()} | {:error, Ecto.Changeset.t()}
  def delete(friend), do: Repo.delete(friend)

  @doc """
  Subscribes a character to presence updates for another character.

  ## Examples

      iex> subscribe(character, friend_id)
      :ok
  """
  @spec subscribe(Schema.Character.t(), integer()) :: :ok
  def subscribe(char, rcpt_id) do
    Ms2ex.Net.SenderSession.run(char, fn ->
      Phoenix.PubSub.subscribe(Ms2ex.PubSub, "friend_presence:#{rcpt_id}")
    end)
  end

  @doc """
  Unsubscribes a character from presence updates for another character.

  ## Examples

      iex> unsubscribe(character, friend_id)
      :ok
  """
  @spec unsubscribe(Schema.Character.t(), integer()) :: :ok
  def unsubscribe(char, rcpt_id) do
    Ms2ex.Net.SenderSession.run(char, fn ->
      Phoenix.PubSub.unsubscribe(Ms2ex.PubSub, "friend_presence:#{rcpt_id}")
    end)
  end
end
