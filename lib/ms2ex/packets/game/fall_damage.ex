defmodule Ms2ex.Packets.FallDamage do
  import Ms2ex.Packets.PacketWriter

  def bytes(character, damage) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_int(damage)
  end
end
