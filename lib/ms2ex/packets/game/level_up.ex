defmodule Ms2ex.Packets.LevelUp do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_int(character.level)
  end
end
