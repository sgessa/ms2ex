defmodule Ms2ex.Packets.FieldRemoveObject do
  import Ms2ex.Packets.PacketWriter

  def bytes(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
  end
end
