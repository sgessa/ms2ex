defmodule Ms2ex.Packets.SyncPetTamingPoint do
  @behaviour Ms2ex.Packets.Spec

  @moduledoc "Syncs a wild pet's taming points after a taming hit or decay tick."

  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Packets.PacketWriter

  @impl true
  def spec(_command) do
    [pet_object_id: :int, caster_object_id: :int, points: :int]
  end

  # pet object id, the tamer's object id (0 on decay), the current points
  def bytes(%Types.FieldPet{} = field_pet, caster_object_id, points) do
    __MODULE__
    |> build()
    |> put_int(field_pet.object_id)
    |> put_int(caster_object_id)
    |> put_int(points)
  end
end
