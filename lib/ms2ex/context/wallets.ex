defmodule Ms2ex.Context.Wallets do
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema

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

  def find(%Schema.Account{id: account_id}) do
    Schema.AccountWallet
    |> where([w], w.account_id == ^account_id)
    |> limit(1)
    |> Repo.one()
  end

  def find(%Schema.Character{id: character_id}) do
    Schema.Wallet
    |> where([w], w.character_id == ^character_id)
    |> limit(1)
    |> Repo.one()
  end

  def update(%Schema.Character{account_id: account_id} = char, currency, value)
      when currency in @account_currencies do
    Repo.transaction(fn ->
      {_count, [wallet]} =
        Schema.AccountWallet
        |> where([w], w.account_id == ^account_id)
        |> select([w], w)
        |> Repo.update_all(inc: [{currency, value}])

      push(char, Packets.Wallet.update(wallet, currency, value))

      wallet
    end)
  end

  def update(%Schema.Character{id: char_id} = char, currency, value) do
    Repo.transaction(fn ->
      {_count, [wallet]} =
        Schema.Wallet
        |> where([w], w.character_id == ^char_id)
        |> select([w], w)
        |> Repo.update_all(inc: [{currency, value}])

      push(char, Packets.Wallet.update(wallet, currency, value))

      wallet
    end)
  end

  def set(%Schema.Character{account_id: account_id} = char, currency, value)
      when currency in @account_currencies do
    Repo.transaction(fn ->
      old =
        Schema.AccountWallet
        |> Repo.get_by(account_id: account_id)
        |> Map.get(currency)

      {_count, [wallet]} =
        Schema.AccountWallet
        |> where([w], w.account_id == ^account_id)
        |> select([w], w)
        |> Repo.update_all(set: [{currency, value}])

      push(char, Packets.Wallet.update(wallet, currency, value - old))

      wallet
    end)
  end

  def set(%Schema.Character{id: char_id} = char, currency, value) do
    Repo.transaction(fn ->
      old =
        Schema.Wallet
        |> Repo.get_by(character_id: char_id)
        |> Map.get(currency)

      {_count, [wallet]} =
        Schema.Wallet
        |> where([w], w.character_id == ^char_id)
        |> select([w], w)
        |> Repo.update_all(set: [{currency, value}])

      push(char, Packets.Wallet.update(wallet, currency, value - old))

      wallet
    end)
  end

  def currency_type(currency), do: Map.get(@types, currency)
end
