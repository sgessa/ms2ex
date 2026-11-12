defmodule Ms2ex.Packets.FieldRemovePet do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Packets

  import Packets.PacketWriter

  def remove_pet(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
  end

  @impl true
  def spec(_command), do: [object_id: :int]
end
