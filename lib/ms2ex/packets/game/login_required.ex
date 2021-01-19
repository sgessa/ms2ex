defmodule Ms2ex.Packets.LoginRequired do
  import Ms2ex.Packets.PacketWriter

  def bytes(account_id) do
    __MODULE__
    |> build()
    |> put_byte(0x17)
    |> put_long(account_id)
    |> put_int()
    |> put_byte()
    |> put_long()
    |> put_int(0x1)
    |> put_int()
    |> put_int()
    |> put_long()
  end
end
