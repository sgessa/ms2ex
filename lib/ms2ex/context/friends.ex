defmodule Ms2ex.Friends do
  alias Ms2ex.{Character, Friend, Repo}

  def add(%Character{} = character, %Character{} = friend, message) do
    <<guid::signed-integer-size(64)>> = :crypto.strong_rand_bytes(8)

    src =
      character
      |> Ecto.build_assoc(:friends)
      |> Friend.add(friend, %{shared_id: guid, status: :pending, message: message})

    dst =
      friend
      |> Ecto.build_assoc(:friends)
      |> Friend.add(character, %{shared_id: guid, status: :accepted, message: message})

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
end
