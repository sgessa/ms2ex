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

  def add(%Character{} = character, %Character{} = friend, message) do
    <<guid::integer-size(32)>> = :crypto.strong_rand_bytes(4)

    src =
      character
      |> Ecto.build_assoc(:friends)
      |> Friend.add(friend, %{shared_id: guid, status: :pending, message: message})

    dst =
      friend
      |> Ecto.build_assoc(:friends)
      |> Friend.add(character, %{
        shared_id: guid,
        is_request: true,
        status: :accepted,
        message: message
      })

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

  def update(%Friend{} = friend, attrs) do
    friend
    |> Friend.changeset(attrs)
    |> Repo.update()
  end

  def delete(shared_id) do
    Friend
    |> where([f], f.shared_id == ^shared_id)
    |> Repo.delete_all()
  end
end
