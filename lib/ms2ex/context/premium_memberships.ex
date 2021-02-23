defmodule Ms2ex.PremiumMemberships do
  alias Ms2ex.{PremiumMembership, Repo}

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
      %PremiumMembership{expires_at: current_expiration} = membership ->
        new_expiration = DateTime.add(current_expiration, expiration, :second)
        update(membership, %{expires_at: new_expiration})

      _ ->
        expires_at = DateTime.utc_now() |> DateTime.add(expiration, :second)
        create(%{account_id: account_id, expires_at: expires_at})
    end
  end

  def get(account_id) do
    Repo.get_by(PremiumMembership, account_id: account_id)
  end

  defp create(attrs) do
    %PremiumMembership{}
    |> PremiumMembership.changeset(attrs)
    |> Repo.insert()
  end

  defp update(membership, attrs) do
    membership
    |> PremiumMembership.changeset(attrs)
    |> Repo.update()
  end
end
