defmodule Ms2ex.Net.Listener do
  use GenServer

  require Logger

  def start_link(opts) do
    log_start(opts)
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {:ok, socket} =
      :gen_tcp.listen(opts.port, [
        :binary,
        active: false,
        ip: host_tuple(opts.host),
        nodelay: true
      ])

    send(self(), :accept)
    {:ok, Map.put(opts, :socket, socket)}
  end

  def handle_info(:accept, %{socket: socket} = state) do
    with {:ok, client_socket} <- :gen_tcp.accept(socket),
         {:ok, _pid} <- Ms2ex.Net.Session.start(%{state | socket: client_socket}) do
      log_start(state)
    end

    send(self(), :accept)

    {:noreply, state}
  end

  defp log_start(%{type: :channel} = conf) do
    "World #{conf.world_name} (Channel #{conf.channel_id}) is running on #{conf.host}:#{conf.port}"
    |> Logger.info()
  end

  defp log_start(%{type: :login, host: host, port: port}) do
    Logger.info("Login Server is running on #{host}:#{port}")
  end

  defp log_start(%{type: :world_login, host: host, port: port, world_name: world}) do
    Logger.info("World #{world} Login Server is running on #{host}:#{port}")
  end

  defp host_tuple(host) do
    host
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end
end
