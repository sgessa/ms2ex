defmodule Ms2ex.Packets.KeyTable do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    request: 0x0,
    send_hotbars: 0x7
  }

  def request() do
    __MODULE__
    |> build()
    |> put_byte(@modes.request)
    |> put_bool(true)
  end
end
