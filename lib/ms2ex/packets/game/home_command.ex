defmodule Ms2ex.Packets.HomeCommand do
  import Ms2ex.Packets.PacketWriter

  @load 0x0

  def load(account_id) do
    __MODULE__
    |> build()
    |> put_byte(@load)
    |> put_long(account_id)
    |> put_long(0)
  end
end
