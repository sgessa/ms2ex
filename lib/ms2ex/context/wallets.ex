defmodule Ms2ex.Wallets do
  alias Ms2ex.{Character, Packets, Repo, Wallet}

  import Ecto.Query, only: [where: 3]

  def update(%Character{id: char_id} = char, currency, value) do
    Repo.transaction(fn ->
      Wallet
      |> where([w], w.character_id == ^char_id)
      |> Repo.update_all(inc: [{currency, value}])

      wallet = Repo.get_by(Wallet, character_id: char_id)

      send(char.session_pid, {:push, Packets.Wallet.update(wallet, currency)})

      wallet
    end)
  rescue
    _ ->
      :error
  end
end
