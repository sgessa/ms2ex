defmodule Ms2ex.Release do
  @moduledoc """
  Release-time tasks (database creation and migrations) run through
  `bin/ms2ex eval` before the application starts.
  """

  def create_db do
    case Ecto.Adapters.Postgres.storage_up(repo_config()) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, reason} -> raise "could not create database: #{inspect(reason)}"
    end
  end

  def migrate do
    Ecto.Migrator.with_repo(Ms2ex.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  defp repo_config do
    Application.get_env(:ms2ex, Ms2ex.Repo)
  end
end
