defmodule Ms2ex.Packets.Mail do
  import Ms2ex.Packets.PacketWriter

  @notify 0x0E

  def notify(unread_count \\ 0, alert \\ false) do
    __MODULE__
    |> build()
    |> put_byte(@notify)
    |> put_int(unread_count)
    |> put_bool(alert)
    |> put_int(unread_count)
  end
end
