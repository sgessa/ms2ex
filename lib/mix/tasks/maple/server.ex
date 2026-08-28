defmodule Mix.Tasks.Maple.Server do
  use Mix.Task

  @shortdoc "Starts the application and all its servers"

  @moduledoc """
  Starts the application with both its game TCP listeners (login, world login
  and channel servers) and the Phoenix web endpoint.

  To start only the game TCP listeners, use `mix maple.game`. To serve only
  the web endpoint, use `mix phx.server`.

  The `--no-halt` flag is automatically added so the servers keep running.

  ## Command line options

  This task accepts the same command-line options as `mix run`.
  """

  @impl true
  def run(args) do
    Application.put_env(:ms2ex, :start_game_servers, true, persistent: true)
    Application.put_env(:phoenix, :serve_endpoints, true, persistent: true)
    Mix.Tasks.Run.run(run_args() ++ args)
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
