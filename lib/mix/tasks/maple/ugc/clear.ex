defmodule Mix.Tasks.Maple.Ugc.Clear do
  use Mix.Task

  @shortdoc "Deletes every uploaded user generated content file"

  @moduledoc """
  Removes the configured UGC data directory.

  Uploaded files are keyed by ids the database hands out, so they are only
  meaningful next to the database that produced them. `mix ecto.reset` runs
  this task for that reason.
  """

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")

    case data_dir() do
      dir when is_binary(dir) and dir != "/" ->
        File.rm_rf!(dir)
        Mix.shell().info("Cleared UGC data in #{dir}")

      dir ->
        Mix.raise("Refusing to clear an unexpected UGC data dir: #{inspect(dir)}")
    end
  end

  defp data_dir do
    :ms2ex
    |> Application.get_env(Ms2ex, [])
    |> Keyword.get(:ugc, %{})
    |> Map.get(:data_dir)
  end
end
