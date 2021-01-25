defmodule Ms2ex.Packets.GameToLogin do
  import Ms2ex.Packets.PacketWriter

  @modes %{success: 0x0}

  def bytes(auth_data) do
    config = Application.get_env(:ms2ex, Ms2ex)
    endpoint = config[:login]

    __MODULE__
    |> build()
    |> put_byte(@modes.success)
    |> put_ip_address(endpoint.host)
    |> put_short(endpoint.port)
    |> put_int(auth_data.token_a)
    |> put_int(auth_data.token_b)
    |> put_int(62_000_000)
  end
end
