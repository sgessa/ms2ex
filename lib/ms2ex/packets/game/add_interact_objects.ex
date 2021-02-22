defmodule Ms2ex.Packets.AddInteractObjects do
  import Ms2ex.Packets.PacketWriter

  def bytes(objects) do
    __MODULE__
    |> build()
    |> put_byte(0x8)
    |> put_int(length(objects))
    |> reduce(objects, fn object, packet ->
      packet
      |> put_string(object.uuid)
      |> put_byte(0x1)
      |> put_byte(0x1)
    end)
  end
end
