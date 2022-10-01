defmodule Ms2ex.Packets.ServerList do
  import Ms2ex.Packets.PacketWriter

  @mod_set 0x1

  def bytes() do
    config = Application.get_env(:ms2ex, Ms2ex)
    worlds = [config[:world]]

    __MODULE__
    |> build()
    |> put_byte(@mod_set)
    |> put_int(length(worlds))
    |> reduce(Enum.with_index(worlds), fn world, packet ->
      put_world(packet, world)
    end)
  end

  def put_world(packet, {world, idx}) do
    login_servers = 1
    channels = length(world.channels)

    packet
    |> put_ustring(world.name)
    |> put_byte(idx + 1)
    |> put_short(login_servers)
    |> put_ustring(world.login.host)
    |> put_short(world.login.port)
    |> put_int(200)
    |> put_short(channels)
    |> reduce(1..channels, fn channel_id, packet ->
      put_short(packet, channel_id)
    end)
  end
end
