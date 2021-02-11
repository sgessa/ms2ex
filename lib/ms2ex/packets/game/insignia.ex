defmodule Ms2ex.Packets.Insignia do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def update(character, insignia_id, enabled) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_short(insignia_id)
    |> put_bool(enabled)
  end
end
