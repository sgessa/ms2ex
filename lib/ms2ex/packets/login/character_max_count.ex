defmodule Ms2ex.Packets.CharacterMaxCount do
  import Ms2ex.Packets.PacketWriter

  def set_max(unlocked, total) do
    __MODULE__
    |> build()
    |> put_int(unlocked)
    |> put_int(total)
  end
end
