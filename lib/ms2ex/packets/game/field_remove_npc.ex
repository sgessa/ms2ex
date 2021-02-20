defmodule Ms2ex.Packets.FieldRemoveNpc do
  import Ms2ex.Packets.PacketWriter

  def bytes(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
  end
end
