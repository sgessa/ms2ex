defmodule Ms2ex.Wallets do
  alias Ms2ex.{Account, AccountWallet, Character, Packets, Repo, Wallet}

  import Ecto.Query, except: [update: 2]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @account_currencies [:event_merets, :game_merets, :merets, :meso_tokens]

  @types %{
    event_merets: 0x9,
    game_merets: 0x8,
    havi_fruits: 0x6,
    merets: 0x7,
    mesos: 0x0,
    meso_tokens: 0x10,
    rues: 0x5,
    trevas: 0x4,
    valor_tokens: 0x3
  }

  def find(%Account{id: account_id}) do
    AccountWallet
    |> where([w], w.account_id == ^account_id)
    |> limit(1)
    |> Repo.one()
  end

  def find(%Character{id: character_id}) do
    Wallet
    |> where([w], w.character_id == ^character_id)
    |> limit(1)
    |> Repo.one()
  end

  def update(%Character{account_id: account_id} = char, currency, value)
      when currency in @account_currencies do
    Repo.transaction(fn ->
      AccountWallet
      |> where([w], w.account_id == ^account_id)
      |> Repo.update_all(inc: [{currency, value}])

      wallet = Repo.get_by(AccountWallet, account_id: account_id)
      push(char, Packets.Wallet.update(wallet, currency))

      wallet
    end)
  rescue
    _ ->
      :error
  end

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

  def currency_type(currency), do: Map.get(@types, currency)
end
