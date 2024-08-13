defmodule Ms2ex.Packets.SkillCancel do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(skill_cast) do
    __MODULE__
    |> build()
    |> put_long(skill_cast.id)
    |> put_int(skill_cast.caster.object_id)
  end
end
