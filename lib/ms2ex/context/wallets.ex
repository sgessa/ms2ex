defmodule Ms2ex.Wallets do
  alias Ms2ex.{Character, Packets, Repo, Wallet}

  import Ecto.Query, only: [where: 3]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def update(%Character{id: char_id} = char, currency, value) do
    Repo.transaction(fn ->
      Wallet
      |> where([w], w.character_id == ^char_id)
      |> Repo.update_all(inc: [{currency, value}])

      wallet = Repo.get_by(Wallet, character_id: char_id)
      push(char, Packets.Wallet.update(wallet, currency))

      wallet
    end)
  rescue
    _ ->
      :error
  end
end
