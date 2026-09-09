defmodule Ms2ex.Context.PremiumMemberships do
  import Ecto.Query, only: [lock: 2, where: 3]

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @doc "Returns the claimed Premium Club benefit ids for an account."
  def claimed(account_id) do
    case Repo.get(Schema.Account, account_id) do
      %Schema.Account{premium_rewards_claimed: claimed} when is_list(claimed) -> claimed
      _ -> []
    end
  end

  @doc "Atomically records a benefit claim, returning `:already_claimed` when needed."
  def claim(account_id, benefit_id) do
    Repo.transaction(fn ->
      account =
        Schema.Account
        |> where([a], a.id == ^account_id)
        |> lock("FOR UPDATE")
        |> Repo.one!()

      claimed = account.premium_rewards_claimed || []

      if benefit_id in claimed do
        Repo.rollback(:already_claimed)
      else
        {:ok, _account} =
          account
          |> Schema.Account.changeset(%{premium_rewards_claimed: [benefit_id | claimed]})
          |> Repo.update()

        [benefit_id | claimed]
      end
    end)
  end

  @doc "Charges Merets and extends membership in one database transaction."
  def purchase(%Schema.Character{account_id: account_id} = character, price, period_hours)
      when is_integer(price) and price > 0 and is_integer(period_hours) and period_hours > 0 do
    Repo.transaction(fn ->
      debit_merets(account_id, price)
      membership = extend_locked(account_id, period_hours)

      wallet = Repo.get_by!(Schema.AccountWallet, account_id: account_id)

      Ms2ex.Net.SenderSession.push(
        character,
        Ms2ex.Packets.Wallet.update(wallet, :merets, -price)
      )

      {wallet, membership}
    end)
  end

  defp debit_merets(account_id, price) do
    Schema.AccountWallet
    |> where([w], w.account_id == ^account_id and w.merets >= ^price)
    |> Repo.update_all(inc: [merets: -price])
    |> case do
      {1, _} -> :ok
      _ -> Repo.rollback(:insufficient_funds)
    end
  end

  defp extend_locked(account_id, period_hours) do
    Schema.PremiumMembership
    |> where([m], m.account_id == ^account_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
    |> case do
      nil ->
        expires_at = DateTime.add(DateTime.utc_now(), period_hours, :hour)
        {:ok, membership} = create(%{account_id: account_id, expires_at: expires_at})
        membership

      membership ->
        base = if expired?(membership), do: DateTime.utc_now(), else: membership.expires_at
        expires_at = DateTime.add(base, period_hours, :hour)
        {:ok, membership} = update(membership, %{expires_at: expires_at})
        membership
    end
  end

  @doc "Clears the daily claimed-benefit list for every account."
  def reset_claimed do
    Repo.update_all(Schema.Account, set: [premium_rewards_claimed: []])
    :ok
  end

  def create_or_extend(account_id, period_hours) do
    Repo.transaction(fn ->
      case create_or_update(account_id, period_hours) do
        {:ok, membership} -> membership
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def extend_coupon(account_id, period_hours),
    do: create_or_extend(account_id, period_hours)

  defp create_or_update(account_id, period_hours) do
    case get(account_id) do
      %Schema.PremiumMembership{expires_at: current_expiration} = membership ->
        base = if expired?(membership), do: DateTime.utc_now(), else: current_expiration
        new_expiration = DateTime.add(base, period_hours, :hour)
        update(membership, %{expires_at: new_expiration})

      _ ->
        expires_at = DateTime.utc_now() |> DateTime.add(period_hours, :hour)
        create(%{account_id: account_id, expires_at: expires_at})
    end
  end

  def get(account_id) do
    Repo.get_by(Schema.PremiumMembership, account_id: account_id)
  end

  defp create(attrs) do
    %Schema.PremiumMembership{}
    |> Schema.PremiumMembership.changeset(attrs)
    |> Repo.insert()
  end

  defp update(membership, attrs) do
    membership
    |> Schema.PremiumMembership.changeset(attrs)
    |> Repo.update()
  end

  def expired?(%{expires_at: expires_at}) do
    now = DateTime.utc_now()

    case DateTime.compare(expires_at, now) do
      :gt -> false
      _ -> true
    end
  end

  def active?(account_id) do
    not is_nil(active(account_id))
  end

  def active(account_id) do
    case get(account_id) do
      %Schema.PremiumMembership{} = membership ->
        if expired?(membership), do: nil, else: membership

      _ ->
        nil
    end
  end
end
