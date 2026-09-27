defmodule Ms2ex.Packets.ChangeBackground do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  # swaps the field's background texture; the named dds file rides the
  # packet verbatim (cinematic beats replay the world behind a backdrop)
  def bytes(dds) do
    __MODULE__
    |> build()
    |> put_ustring(dds)
  end
end
