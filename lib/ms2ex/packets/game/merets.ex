defmodule Ms2ex.Packets.Merets do
  import Ms2ex.Packets.PacketWriter

  def update(amount) do
    __MODULE__
    |> build()
    |> put_long()
    |> put_long(amount)
    |> put_long(0)
    |> put_long(0)
    |> put_long()
  end
end
