defmodule Ms2ex.Wallets do
  alias Ms2ex.{Character, Repo, Wallet}

  import Ecto.Query, only: [where: 3]

  def update(%Character{id: character_id}, currency, value) do
    Repo.transaction(fn ->
      Wallet
      |> where([w], w.character_id == ^character_id)
      |> Repo.update_all(inc: [{currency, value}])

      Repo.get_by(Wallet, character_id: character_id)
    end)
  rescue
    _ ->
      :error
  end
end
