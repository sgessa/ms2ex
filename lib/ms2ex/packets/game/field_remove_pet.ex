defmodule Ms2ex.Packets.FieldRemovePet do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def remove_pet(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
  end
end
