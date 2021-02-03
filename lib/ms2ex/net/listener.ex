defmodule Ms2ex.Net.Listener do
  require Logger

  def start_link(conf) do
    log_start(conf)

    :ranch.start_listener(
      conf[:id],
      100,
      :ranch_tcp,
      [port: conf.port],
      Ms2ex.Net.Session,
      conf
    )
  end

  def child_spec(opts) do
    %{
      id: opts[:id],
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  defp log_start(%{type: :channel} = conf) do
    Logger.info(
      "World #{conf.world_name} (Channel #{conf.channel_id}) is running on 0.0.0.0:#{conf.port}"
    )
  end

  defp log_start(%{type: :login} = conf) do
    Logger.info("Login Server is running on 0.0.0.0:#{conf.port}")
  end

  defp log_start(%{type: :world_login} = conf) do
    Logger.info("World #{conf.world_name} Login Server is running on 0.0.0.0:#{conf.port}")
  end
end
