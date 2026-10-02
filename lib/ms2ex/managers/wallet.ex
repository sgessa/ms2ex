defmodule Ms2ex.Managers.Wallet do
  @moduledoc """
  Per-character wallet state: the character's balances (mesos, valor tokens,
  trevas, rues, havi fruits) and a copy of the account balances (merets,
  event merets, game merets, meso tokens) it spends.

  Credits clamp at the currency's cap and report the overflow; debits fail
  wholesale with `{:error, :insufficient_funds}` when the balance cannot
  cover them — balances never go negative. Every change persists through
  `Ms2ex.Context.Wallets` and pushes the wallet packet with the applied
  delta.

  The account wallet copy is per character manager: two characters of the
  same account online at once each hold their own view, matching the
  per-session currency of the official servers.
  """

  use GenServer
  use Ms2ex.Managers.Managed, prefix: "wallets", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

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

  def start(%Schema.Character{} = character) do
    case GenServer.start(__MODULE__, character, name: process_name(character.id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def stop(%Schema.Character{id: id}), do: stop(id)

  def stop(id) when is_integer(id) do
    case Process.whereis(process_name(id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  @doc "The character's balances."
  def find(%Schema.Character{id: id}), do: call(id, :find_character)

  @doc "The account balances of the character's account."
  def account_wallet(%Schema.Character{account_id: account_id} = character) do
    call(character.id, {:find_account, account_id})
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

  def currency_type(currency), do: Map.get(@types, currency)

  @doc """
  How much of `amount` can actually be applied to the currency: credits
  clamp at the cap, debits at zero.
  """
  def can_add(%Schema.Character{} = character, currency, amount) do
    call(character.id, {:can_add, currency, amount})
  end

  @doc """
  Applies a delta to a wallet. Credits clamp at the currency's cap (the
  packet reports the applied delta and the overflow); debits fail wholesale
  with `{:error, :insufficient_funds}` when the balance cannot cover them.
  """
  def update(%Schema.Character{} = character, currency, delta) do
    call(character.id, {:update, character, currency, delta})
  end

  @doc """
  Withdraws `amount` from a wallet, failing with
  `{:error, :insufficient_funds}` when the balance cannot cover it.
  """
  def debit(%Schema.Character{} = character, currency, amount) do
    call(character.id, {:debit, character, currency, amount})
  end

  @doc "Overwrites a balance, clamping it into `[0, cap]`."
  def set(%Schema.Character{} = character, currency, value) do
    call(character.id, {:set, character, currency, value})
  end

  # ---- Server Callbacks ----

  @impl true
  def init(%Schema.Character{account_id: account_id} = character) do
    {:ok,
     %{
       character_wallet: Context.Wallets.get_character_wallet(character.id),
       account_wallet: Context.Wallets.get_account_wallet(account_id)
     }}
  end

  @impl true
  def handle_call(:find_character, _from, state) do
    {:reply, state.character_wallet, state}
  end

  def handle_call({:find_account, _account_id}, _from, state) do
    {:reply, state.account_wallet, state}
  end

  def handle_call({:can_add, currency, amount}, _from, state) do
    wallet = wallet_for(currency, state)
    {:reply, can_add_balance(balance(wallet, currency), cap(currency), amount), state}
  end

  def handle_call({:update, character, currency, delta}, _from, state) do
    {reply, state} = apply_delta(character, currency, delta, state)
    {:reply, reply, state}
  end

  def handle_call({:debit, character, currency, amount}, _from, state) do
    {reply, state} = apply_delta(character, currency, -amount, state)
    {:reply, reply, state}
  end

  def handle_call({:set, character, currency, value}, _from, state) do
    wallet = wallet_for(currency, state)
    delta = value - balance(wallet, currency)
    {reply, state} = apply_delta(character, currency, delta, state)
    {:reply, reply, state}
  end

  # ---- balance mutation ----

  defp apply_delta(character, currency, delta, state) do
    wallet = wallet_for(currency, state)
    current = balance(wallet, currency)
    cap = cap(currency)
    new = current + delta

    cond do
      delta < 0 and new < 0 ->
        {{:error, :insufficient_funds}, state}

      new > cap ->
        applied = cap - current
        overflow = new - cap
        wallet = %{wallet | currency => cap}
        persist(wallet, character)
        push(character, Packets.Wallet.update(wallet, currency, applied, overflow))
        {{:ok, wallet}, put_wallet(state, wallet)}

      true ->
        wallet = %{wallet | currency => new}
        persist(wallet, character)
        push(character, Packets.Wallet.update(wallet, currency, delta))
        {{:ok, wallet}, put_wallet(state, wallet)}
    end
  end

  defp wallet_for(currency, state) when currency in @account_currencies,
    do: state.account_wallet

  defp wallet_for(currency, state) when currency in @character_currencies,
    do: state.character_wallet

  defp put_wallet(state, wallet) do
    if wallet.__meta__.schema == Schema.AccountWallet do
      %{state | account_wallet: wallet}
    else
      %{state | character_wallet: wallet}
    end
  end

  defp persist(wallet, character) do
    if wallet.__meta__.schema == Schema.AccountWallet do
      Context.Wallets.persist_account_wallet(character.account_id, wallet)
    else
      Context.Wallets.persist_character_wallet(character.id, wallet)
    end
  end

  defp balance(nil, _currency), do: 0
  defp balance(wallet, currency), do: Map.get(wallet, currency, 0)

  defp can_add_balance(current, cap, amount) when amount >= 0,
    do: min(amount, max(cap - current, 0))

  defp can_add_balance(current, _cap, amount), do: max(amount, -current)
end
