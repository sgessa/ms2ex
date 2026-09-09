defmodule Ms2ex.Repo.Migrations.AddPremiumRewardsClaimedToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :premium_rewards_claimed, :binary, null: false, default: "\\x836a"
    end
  end
end
