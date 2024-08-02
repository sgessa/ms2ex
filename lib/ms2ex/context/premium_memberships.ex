defmodule Ms2ex.Context.PremiumMemberships do
  alias Ms2ex.{Repo, Schema}

  def create_or_extend(account_id, expiration) do
    Repo.transaction(fn ->
      case create_or_update(account_id, expiration) do
        {:ok, membership} -> membership
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp create_or_update(account_id, expiration) do
    case get(account_id) do
      %Schema.PremiumMembership{expires_at: current_expiration} = membership ->
        new_expiration = DateTime.add(current_expiration, expiration, :second)
        update(membership, %{expires_at: new_expiration})

      _ ->
        expires_at = DateTime.utc_now() |> DateTime.add(expiration, :second)
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
end
