defmodule Ms2ex.Repo.Migrations.CreateExtensionCitext do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext")
  end
end
