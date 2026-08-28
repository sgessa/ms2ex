defmodule Mix.Tasks.Maple.Game do
  use Mix.Task

  @shortdoc "Starts the application and its game TCP listeners"

  @moduledoc """
  Starts the application and its game TCP listeners (login, world login and
  channel servers) without serving the Phoenix web endpoint.

  This is the game-server counterpart of `mix phx.server`. To also serve the
  web endpoint, use `mix maple.server`.

  The `--no-halt` flag is automatically added so the listeners keep running.

  ## Command line options

  This task accepts the same command-line options as `mix run`.
  """

  @impl true
  def run(args) do
    Application.put_env(:ms2ex, :start_game_servers, true, persistent: true)
    Mix.Tasks.Run.run(run_args() ++ args)
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
