defmodule Ms2ex.Packets.GameToGame do
  import Ms2ex.Packets.PacketWriter

  @modes %{success: 0x0}

  def bytes(channel_id, field_id, auth_data) do
    config = Application.get_env(:ms2ex, Ms2ex)
    [world | _] = config[:worlds]

    channel = Enum.at(world.channels, channel_id - 1) || List.first(world.channels)

    __MODULE__
    |> build()
    |> put_byte(@modes.success)
    |> put_int(auth_data.token_a)
    |> put_int(auth_data.token_b)
    |> put_ip_address(channel.host)
    |> put_short(channel.port)
    |> put_int(field_id)
    |> put_byte()
  end
end
