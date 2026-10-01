defmodule Ms2ex.Context.Wallets do
  @moduledoc """
  Character and account wallets with the client's currency caps: mesos and
  the meret family are unbounded, while token currencies clamp at the
  caps the client's server table carries (honor 5000, karma 75000, lu 2000,
  habi 35000, mentor 10000, mentee 35000). Credits beyond a cap are clamped
  and reported as overflow; debits fail wholesale when the balance is
  insufficient.
  """

  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ecto.Query, except: [update: 2]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @account_currencies [:event_merets, :game_merets, :merets, :meso_tokens]
  @character_currencies [:mesos, :valor_tokens, :trevas, :rues, :havi_fruits]

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

  @no_cap 9_223_372_036_854_775_807
  # the client table carries no meso-token cap; this matches the client's
  # built-in limit
  @meso_token_max 100_000

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

  @doc "The balance a currency may not exceed (the client's server table values)."
  def cap(currency) do
    case currency do
      :valor_tokens -> Storage.Tables.Constants.get(:honor_token_max)
      :trevas -> Storage.Tables.Constants.get(:karma_token_max)
      :rues -> Storage.Tables.Constants.get(:lu_token_max)
      :havi_fruits -> Storage.Tables.Constants.get(:habi_token_max)
      :meso_tokens -> @meso_token_max
      _other -> @no_cap
    end
  end

  @doc """
  How much of `amount` can actually be applied to the currency: credits
  clamp at the cap, debits at zero.
  """
  def can_add(%Schema.Character{account_id: account_id}, currency, amount)
      when currency in @account_currencies do
    wallet = find(%Schema.Account{id: account_id})
    can_add_balance(balance(wallet, currency), cap(currency), amount)
  end

  def can_add(%Schema.Character{} = character, currency, amount)
      when currency in @character_currencies do
    wallet = find(character)
    can_add_balance(balance(wallet, currency), cap(currency), amount)
  end

  @doc """
  Applies a delta to a wallet. Credits clamp at the currency's cap (the
  packet reports the applied delta and the overflow); debits fail wholesale
  with `{:error, :insufficient_funds}` when the balance cannot cover them.
  """
  def update(%Schema.Character{account_id: account_id} = char, currency, delta)
      when currency in @account_currencies and is_integer(delta) do
    Repo.transaction(fn ->
      account_id
      |> fetch_account_wallet()
      |> apply_delta(char, currency, delta)
      |> persist_account_wallet(account_id)
    end)
  end

  def update(%Schema.Character{id: char_id} = char, currency, delta)
      when currency in @character_currencies and is_integer(delta) do
    Repo.transaction(fn ->
      char_id
      |> fetch_character_wallet()
      |> apply_delta(char, currency, delta)
      |> persist_character_wallet(char_id)
    end)
  end

  @doc """
  Withdraws `amount` from a wallet, failing with
  `{:error, :insufficient_funds}` when the balance cannot cover it.
  """
  def debit(%Schema.Character{account_id: account_id} = char, currency, amount)
      when currency in @account_currencies and is_integer(amount) and amount > 0 do
    Repo.transaction(fn ->
      Schema.AccountWallet
      |> where([w], w.account_id == ^account_id and field(w, ^currency) >= ^amount)
      |> select([w], w)
      |> Repo.update_all(inc: [{currency, -amount}])
      |> case do
        {1, [wallet]} ->
          push(char, Packets.Wallet.update(wallet, currency, -amount))
          wallet

        _ ->
          Repo.rollback(:insufficient_funds)
      end
    end)
  end

  def debit(%Schema.Character{id: char_id} = char, currency, amount)
      when currency in @character_currencies and is_integer(amount) and amount > 0 do
    Repo.transaction(fn ->
      Schema.Wallet
      |> where([w], w.character_id == ^char_id and field(w, ^currency) >= ^amount)
      |> select([w], w)
      |> Repo.update_all(inc: [{currency, -amount}])
      |> case do
        {1, [wallet]} ->
          push(char, Packets.Wallet.update(wallet, currency, -amount))
          wallet

        _ ->
          Repo.rollback(:insufficient_funds)
      end
    end)
  end

  @doc "Overwrites a balance, clamping it into `[0, cap]`."
  def set(%Schema.Character{account_id: account_id} = char, currency, value)
      when currency in @account_currencies and is_integer(value) do
    Repo.transaction(fn ->
      wallet = fetch_account_wallet(account_id)
      delta = value - Map.get(wallet, currency, 0)

      wallet
      |> apply_delta(char, currency, delta)
      |> persist_account_wallet(account_id)
    end)
  end

  def set(%Schema.Character{id: char_id} = char, currency, value)
      when currency in @character_currencies and is_integer(value) do
    Repo.transaction(fn ->
      wallet = fetch_character_wallet(char_id)
      delta = value - Map.get(wallet, currency, 0)

      wallet
      |> apply_delta(char, currency, delta)
      |> persist_character_wallet(char_id)
    end)
  end

  def currency_type(currency), do: Map.get(@types, currency)

  # ---- delta application ----

  defp apply_delta(wallet, char, currency, delta) do
    current = Map.get(wallet, currency, 0)
    cap = cap(currency)
    new = current + delta

    cond do
      delta < 0 and new < 0 ->
        Repo.rollback(:insufficient_funds)

      new > cap ->
        applied = cap - current
        overflow = new - cap

        push(
          char,
          Packets.Wallet.update(%{wallet | currency => cap}, currency, applied, overflow)
        )

        %{wallet | currency => cap}

      true ->
        push(char, Packets.Wallet.update(%{wallet | currency => new}, currency, delta))
        %{wallet | currency => new}
    end
  end

  defp persist_account_wallet(wallet, account_id) do
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

    wallet
  end

  defp persist_character_wallet(wallet, char_id) do
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

    wallet
  end

  defp fetch_account_wallet(account_id) do
    Repo.get_by!(Schema.AccountWallet, account_id: account_id)
  end

  defp fetch_character_wallet(char_id) do
    Repo.get_by!(Schema.Wallet, character_id: char_id)
  end

  defp balance(nil, _currency), do: 0
  defp balance(wallet, currency), do: Map.get(wallet, currency, 0)

  defp can_add_balance(current, cap, amount) when amount >= 0,
    do: min(amount, max(cap - current, 0))

  defp can_add_balance(current, _cap, amount), do: max(amount, -current)
end
