defmodule Ms2ex.Packets.ChangeBackground do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  # swaps the field's background texture; the named dds file rides the
  # packet verbatim (cinematic beats replay the world behind a backdrop)
  def bytes(dds) do
    __MODULE__
    |> build()
    # a single-byte (DecodeStrA) string: the client reads this packet's
    # texture name as length-prefixed ascii, not utf-16
    |> put_string(dds)
  end
end
