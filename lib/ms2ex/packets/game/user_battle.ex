defmodule Ms2ex.Packets.UserBattle do
  import Ms2ex.Packets.PacketWriter

  def set_stance(character, flag) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_bool(flag)
  end
end
