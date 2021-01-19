defmodule Ms2ex.Net.LoginServer do
  require Logger

  def start_link(conf) do
    Logger.info("Login Server is running on 0.0.0.0:#{conf.port}")

    :ranch.start_listener(
      __MODULE__,
      100,
      :ranch_tcp,
      [port: conf.port],
      Ms2ex.Net.SessionHandler,
      Map.put(conf, :type, :login)
    )
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
