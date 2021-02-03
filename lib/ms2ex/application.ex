defmodule Ms2ex.Application do
  @moduledoc false

  use Application

  alias Ms2ex.Registries

  @config Application.get_env(:ms2ex, Ms2ex)

  def start(_type, _args) do
    Ms2ex.Metadata.Items.store()
    Ms2ex.Metadata.Maps.store()
    Ms2ex.Metadata.Skills.store()

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
        login_server()
      ] ++ worlds()

    opts = [strategy: :one_for_one, name: Ms2ex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp login_server() do
    opts = Map.merge(@config[:login], %{id: :login_server, type: :login})
    {Ms2ex.Net.Listener, opts}
  end

  defp worlds() do
    worlds = @config[:worlds]

    Enum.reduce(Enum.with_index(worlds), [], fn {world, idx}, worlds ->
      world_id = :"world:#{idx + 1}"

      world_server =
        Supervisor.child_spec({Ms2ex.World, [name: {:via, :swarm, world_id}]}, id: world_id)

      world_login_opts =
        Map.merge(world.login, %{
          id: :"world_login:#{idx + 1}",
          type: :world_login,
          world: world_id,
          world_name: world.name
        })

      world_login = {Ms2ex.Net.Listener, world_login_opts}

      worlds ++ [world_server, world_login] ++ channels(world_id, world)
    end)
  end

  defp channels(world_id, world) do
    Enum.map(Enum.with_index(world.channels), fn {channel, idx} ->
      channel_id = idx + 1
      id = :"#{world_id}:channel:#{channel_id}"

      opts =
        Map.merge(channel, %{
          channel_id: channel_id,
          id: id,
          type: :channel,
          world: world_id,
          world_name: world.name
        })

      {Ms2ex.Net.Listener, opts}
    end)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Ms2exWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
