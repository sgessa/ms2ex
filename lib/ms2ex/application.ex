defmodule Ms2ex.Application do
  @moduledoc false

  use Application

  alias Ms2ex.Registries

  @config Application.get_env(:ms2ex, Ms2ex)

  def start(_type, _args) do
    Registries.SkillCasts.start()

    Ms2ex.Metadata.Insignias.store()
    Ms2ex.Metadata.Items.store()
    Ms2ex.Metadata.Maps.store()
    Ms2ex.Metadata.Npcs.store()
    Ms2ex.Metadata.Skills.store()

    start_login_server()
    start_worlds()

    children = [
      # Start the Ecto repository
      Ms2ex.Repo,
      # Start the Telemetry supervisor
      Ms2exWeb.Telemetry,
      # Start the PubSub system
      # {Phoenix.PubSub, name: Ms2ex.PubSub},
      # Start the Endpoint (http/https)
      # Ms2exWeb.Endpoint
      # Start Session Registry
      {Registries.Sessions, [name: {:via, :swarm, Registries.Sessions}]}
    ]

    world_managers =
      Enum.into(1..length(@config[:worlds]), [], fn idx ->
        name = :"world:#{idx}"
        Supervisor.child_spec({Ms2ex.World, [name: {:via, :swarm, name}]}, id: name)
      end)

    opts = [strategy: :one_for_one, name: Ms2ex.Supervisor]
    Supervisor.start_link(children ++ world_managers, opts)
  end

  defp start_login_server() do
    opts = Map.merge(@config[:login], %{id: :login_server, type: :login})
    Ms2ex.Net.Listener.start(opts)
  end

  defp start_worlds() do
    worlds = @config[:worlds]

    Enum.each(Enum.with_index(worlds), fn {world, idx} ->
      id = :"world_login:#{idx + 1}"
      opts = world_login_options(world, id)
      Ms2ex.Net.Listener.start(opts)

      world_id = :"world:#{idx + 1}"
      start_channels(world, world_id)
    end)
  end

  defp start_channels(world, world_id) do
    Enum.each(Enum.with_index(world.channels), fn {channel, idx} ->
      channel_id = idx + 1
      opts = channel_options(channel, channel_id, world_id, world.name)
      Ms2ex.Net.Listener.start(opts)
    end)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Ms2exWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp channel_options(channel, channel_id, world_id, world_name) do
    id = :"#{world_id}:channel:#{channel_id}"

    Map.merge(channel, %{
      channel_id: channel_id,
      id: id,
      type: :channel,
      world: world_id,
      world_name: world_name
    })
  end

  def world_login_options(world, id) do
    Map.merge(world.login, %{
      id: id,
      type: :world_login,
      world_name: world.name
    })
  end
end
