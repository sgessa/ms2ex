defmodule Ms2ex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Ms2ex.WorldGraph.store()
    # Ms2ex.ProtoMetadata.ChatStickers.store()
    # Ms2ex.ProtoMetadata.ExpTable.store()
    # Ms2ex.ProtoMetadata.Insignias.store()
    # Ms2ex.ProtoMetadata.Items.store()
    # Ms2ex.Storage.Items.ConstantOptions.store()
    # Ms2ex.Storage.Items.StaticOptions.store()
    # Ms2ex.Storage.Items.RandomOptions.store()
    # Ms2ex.Storage.Items.RangeOptions.store()
    # Ms2ex.Storage.Items.PickOptions.store()
    # Ms2ex.ProtoMetadata.Maps.store()
    # Ms2ex.ProtoMetadata.MapEntities.store()
    # Ms2ex.ProtoMetadata.MagicPaths.store()
    # Ms2ex.ProtoMetadata.Npcs.store()
    # Ms2ex.ProtoMetadata.Skills.store()

    children =
      [
        # Start the Ecto repository
        Ms2ex.Repo,
        # Start Redis cache server
        {Redix, [port: 5556, name: Ms2ex.Redix]},
        # Start the Telemetry supervisor
        Ms2exWeb.Telemetry,
        # Start the PubSub system
        {Phoenix.PubSub, name: Ms2ex.PubSub},
        # Start the Endpoint (http/https)
        Ms2exWeb.Endpoint,
        # Start Managers
        {Ms2ex.PartyManager, [name: Ms2ex.PartyManager]},
        {Ms2ex.SessionManager, [name: Ms2ex.SessionManager]},
        # Start TCP Listeners
        server_tcp_chidspec(login_server_opts()),
        server_tcp_chidspec(world_login_opts())
      ] ++ channel_listeners()

    opts = [strategy: :one_for_one, name: Ms2ex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp login_server_opts() do
    config = Application.get_env(:ms2ex, Ms2ex)
    Map.merge(config[:login], %{id: :login_listener, type: :login_server})
  end

  defp world_login_opts() do
    config = Application.get_env(:ms2ex, Ms2ex)

    Map.merge(config[:world][:login], %{
      id: :world_listener,
      type: :world_login,
      world_name: config[:world][:name]
    })
  end

  defp channel_listeners() do
    config = Application.get_env(:ms2ex, Ms2ex)

    Enum.map(Enum.with_index(config[:world][:channels]), fn {channel, idx} ->
      channel_id = idx + 1
      listener_id = :"channel:#{channel_id}"

      args = Map.merge(channel, %{id: listener_id, type: :channel, channel_id: channel_id})
      server_tcp_chidspec(args)
    end)
  end

  defp server_tcp_chidspec(server_config) do
    :ranch.child_spec(
      # ensure unique name!
      server_config.id,
      :ranch_tcp,
      [{:port, server_config.port}],
      Ms2ex.Net.Session,
      [server_config]
    )
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Ms2exWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
