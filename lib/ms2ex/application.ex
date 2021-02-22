defmodule Ms2ex.Application do
  @moduledoc false

  use Application

  alias Ms2ex.Registries

  @config Application.get_env(:ms2ex, Ms2ex)

  def start(_type, _args) do
    Registries.SkillCasts.start()

    Ms2ex.Metadata.ChatStickers.store()
    Ms2ex.Metadata.ExpTable.store()
    Ms2ex.Metadata.Insignias.store()
    Ms2ex.Metadata.ItemStats.store()
    Ms2ex.Metadata.Items.store()
    Ms2ex.Metadata.Maps.store()
    Ms2ex.Metadata.MapBlocks.store()
    Ms2ex.Metadata.MobSpawns.store()
    Ms2ex.Metadata.Npcs.store()
    Ms2ex.Metadata.Skills.store()

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
      {Registries.Sessions, [name: {:via, :swarm, Registries.Sessions}]},
      {Ms2ex.Net.Listener, login_server_opts()}
    ]

    world_managers =
      Enum.into(1..length(@config[:worlds]), [], fn idx ->
        name = :"world:#{idx}"
        Supervisor.child_spec({Ms2ex.WorldServer, [name: {:via, :swarm, name}]}, id: name)
      end)

    opts = [strategy: :one_for_one, name: Ms2ex.Supervisor]
    Supervisor.start_link(children ++ world_managers ++ worlds(), opts)
  end

  defp login_server_opts() do
    Map.merge(@config[:login], %{id: :login_server, type: :login})
  end

  defp worlds() do
    worlds = @config[:worlds]

    Enum.reduce(Enum.with_index(worlds), [], fn {world, idx}, processes ->
      listener_id = :"world_login:#{idx + 1}"
      processes = processes ++ [world_spec(listener_id, world)]

      world_id = :"world:#{idx + 1}"
      processes ++ channels(world, world_id)
    end)
  end

  def world_spec(id, world) do
    args = world_login_options(world)
    Supervisor.child_spec({Ms2ex.Net.Listener, args}, id: id)
  end

  def world_login_options(world) do
    Map.merge(world.login, %{type: :world_login, world_name: world.name})
  end

  defp channels(world, world_id) do
    Enum.reduce(Enum.with_index(world.channels), [], fn {channel, idx}, processes ->
      channel_id = idx + 1
      listener_id = :"#{world_id}:channel:#{channel_id}"

      args = channel_options(channel, channel_id, world_id, world.name)
      processes ++ [channel_spec(listener_id, args)]
    end)
  end

  def channel_spec(id, args) do
    Supervisor.child_spec({Ms2ex.Net.Listener, args}, id: id)
  end

  defp channel_options(channel, channel_id, world_id, world_name) do
    Map.merge(channel, %{
      channel_id: channel_id,
      type: :channel,
      world: world_id,
      world_name: world_name
    })
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Ms2exWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
