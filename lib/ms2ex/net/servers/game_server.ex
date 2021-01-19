defmodule Ms2ex.Net.GameServer do
  require Logger

  def start_link(conf) do
    Logger.info(
      "World #{conf.name} (Channel #{conf.channel_id}) is running on 0.0.0.0:#{conf.port}"
    )

    :ranch.start_listener(
      :"channel_#{conf[:channel_id]}",
      100,
      :ranch_tcp,
      [port: conf.port],
      Ms2ex.Net.SessionHandler,
      Map.put(conf, :type, :channel)
    )
  end

  def child_spec(opts) do
    %{
      id: :"channel_#{opts[:channel_id]}",
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
