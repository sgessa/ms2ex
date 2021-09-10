defmodule Ms2ex.Friends do
  alias Ms2ex.{Character, Friend, Repo}

  import Ecto.Query

  def get_by_character_and_shared_id(char_id, shared_id, preload_rcpt? \\ false) do
    Friend
    |> where([f], f.shared_id == ^shared_id and f.rcpt_id != ^char_id)
    |> maybe_preload_rcpt(preload_rcpt?)
    |> limit(1)
    |> Repo.one()
  end

  defp maybe_preload_rcpt(query, true), do: preload(query, [_f], [:rcpt])
  defp maybe_preload_rcpt(query, _), do: query

  def send_request(%Character{} = character, %Character{} = friend, message) do
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
      |> Friend.add(friend, src_attrs)

    dst =
      friend
      |> Ecto.build_assoc(:friends)
      |> Friend.add(character, dst_attrs)

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

  def block(%Character{} = character, %Character{} = rcpt, reason) do
    shared_id = Ms2ex.generate_id()
    attrs = %{shared_id: shared_id, block_reason: reason, status: :blocked}

    character
    |> Ecto.build_assoc(:friends)
    |> Friend.block(rcpt, attrs)
    |> Repo.insert()
  end

  def block_friend(src, dst, reason) do
    change = Friend.block_friend(src, reason)

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

  def update(%Friend{} = friend, attrs) do
    friend
    |> Friend.changeset(attrs)
    |> Repo.update()
  end

  def delete_all(shared_id) do
    Friend
    |> where([f], f.shared_id == ^shared_id)
    |> Repo.delete_all()
  end

  def delete(friend), do: Repo.delete(friend)
end
