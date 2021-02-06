defmodule Ms2ex.Packets.Mesos do
  import Ms2ex.Packets.PacketWriter

  def update(amount) do
    __MODULE__
    |> build()
    |> put_long(amount)
    |> put_int()
  end
end
