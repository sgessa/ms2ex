defmodule Ms2ex.Context.Wallets do
  @moduledoc """
  Row persistence for character and account wallets. Balance mutations,
  caps and packet pushes live in `Ms2ex.Managers.Wallet`, which owns the
  in-memory balances for an online character.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ecto.Query, except: [update: 2]

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

  def get_character_wallet(character_id) do
    Repo.get_by!(Schema.Wallet, character_id: character_id)
  end

  def get_account_wallet(account_id) do
    case Repo.get_by(Schema.AccountWallet, account_id: account_id) do
      nil -> Repo.insert!(%Schema.AccountWallet{account_id: account_id})
      wallet -> wallet
    end
  end

  def persist_character_wallet(char_id, wallet) do
    Schema.Wallet
    |> where([w], w.character_id == ^char_id)
    |> Repo.update_all(
      set: [
        mesos: wallet.mesos,
        valor_tokens: wallet.valor_tokens,
        trevas: wallet.trevas,
        rues: wallet.rues,
        havi_fruits: wallet.havi_fruits
      ]
    )

    :ok
  end

  def persist_account_wallet(account_id, wallet) do
    Schema.AccountWallet
    |> where([w], w.account_id == ^account_id)
    |> Repo.update_all(
      set: [
        merets: wallet.merets,
        event_merets: wallet.event_merets,
        game_merets: wallet.game_merets,
        meso_tokens: wallet.meso_tokens
      ]
    )

    :ok
  end

  def currency_type(currency), do: Map.get(@types, currency)
end
