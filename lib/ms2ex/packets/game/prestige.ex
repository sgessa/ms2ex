defmodule Ms2ex.Packets.Prestige do
  import Ms2ex.Packets.PacketWriter

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_long(character.prestige_exp)
    |> put_int(character.prestige_level)
    |> put_long(character.prestige_exp)
    |> put_int(0)
  end
end
