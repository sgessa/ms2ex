defmodule Ms2ex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Ms2ex.Registries

  def start(_type, _args) do
    config = Application.get_env(:ms2ex, Ms2ex)

    Ms2ex.Metadata.Items.store()
    Ms2ex.Metadata.ListSkillMetadata.store()

    # Start Character Registry (ETS)
    Registries.Characters.start()

    children =
      [
        # Start the Ecto repository
        Ms2ex.Repo,
        # Start the Telemetry supervisor
        Ms2exWeb.Telemetry,
        # Start the PubSub system
        # {Phoenix.PubSub, name: Ms2ex.PubSub},
        # Start the Endpoint (http/https)
        # Ms2exWeb.Endpoint
        # Start Session Registry
        {Registries.Sessions, [name: {:via, :swarm, Registries.Sessions}]},
        # Start Login Server
        {Ms2ex.Net.LoginServer, config[:login]}
      ] ++
        worlds(config[:worlds])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ms2ex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp worlds(worlds) do
    Enum.map(worlds, fn world ->
      Enum.map(Enum.with_index(world.channels), fn {channel, idx} ->
        opts = Map.merge(channel, %{channel_id: idx + 1, name: world.name})
        {Ms2ex.Net.GameServer, opts}
      end)
    end)
    |> List.flatten()
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Ms2exWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
