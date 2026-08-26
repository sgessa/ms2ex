defmodule Ms2ex.Packets.SkillMacro do
  import Ms2ex.Packets.PacketWriter

  def load do
    build(__MODULE__)
    |> put_byte(0x0)
    |> put_int(0)
  end
end
