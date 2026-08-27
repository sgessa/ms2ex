defmodule Ms2ex.Packets.StateSkill do
  import Ms2ex.Packets.PacketWriter

  def bytes(character, skill_id, cast_uid, state) do
    __MODULE__
    |> build()
    |> put_byte(0x6)
    |> put_int(character.object_id)
    |> put_int()
    |> put_long(cast_uid)
    |> put_int(skill_id)
    |> put_int(state)
  end
end
