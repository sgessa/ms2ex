defmodule Ms2ex.Application do
  @moduledoc false

  use Application

  @config Application.get_env(:ms2ex, Ms2ex)
  @world @config[:world]

  def start(_type, _args) do
    Ms2ex.WorldGraph.store()

    Ms2ex.Metadata.ChatStickers.store()
    Ms2ex.Metadata.ExpTable.store()
    Ms2ex.Metadata.Insignias.store()
    Ms2ex.Metadata.Items.store()
    Ms2ex.Metadata.Maps.store()
    Ms2ex.Metadata.MapEntities.store()
    Ms2ex.Metadata.MagicPaths.store()
    Ms2ex.Metadata.Npcs.store()
    Ms2ex.Metadata.Skills.store()

    children =
      [
        # Start the Ecto repository
        Ms2ex.Repo,
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
    Map.merge(@config[:login], %{id: :login_listener, type: :login_server})
  end

  defp world_login_opts() do
    Map.merge(@world[:login], %{
      id: :world_listener,
      type: :world_login,
      world_name: @world[:name]
    })
  end

  defp channel_listeners() do
    Enum.map(Enum.with_index(@world[:channels]), fn {channel, idx} ->
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
