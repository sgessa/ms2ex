defmodule Ms2ex.Repo.Migrations.AddMasteriesToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :masteries, :binary, null: true
      add :gathering_counts, :binary, null: true
      add :mastery_rewards_claimed, :binary, null: true
    end
  end
end
