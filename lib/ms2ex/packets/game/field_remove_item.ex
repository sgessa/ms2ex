defmodule Ms2ex.Packets.FieldRemoveItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
  end
end
