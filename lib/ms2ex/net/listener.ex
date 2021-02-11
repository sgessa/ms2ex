defmodule Ms2ex.Net.Listener do
  require Logger

  def start(opts) do
    log_start(opts)
    :ranch.start_listener(opts.id, :ranch_tcp, [port: opts.port], Ms2ex.Net.Session, opts)
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
