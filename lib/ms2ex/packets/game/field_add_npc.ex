defmodule Ms2ex.Packets.FieldAddNpc do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(npc) do
    branches = 0

    __MODULE__
    |> build()
    |> put_int(npc.object_id)
    |> put_int(npc.id)
    |> put_coord(npc.position)
    |> put_coord()
    |> put_stats()
    |> put_byte()
    |> put_short(branches)
    |> put_long()
    |> put_byte()
    |> put_int(0x1)
    |> put_int()
    |> put_byte()
  end

  def put_stats(packet) do
    flag = 0x23

    packet
    |> put_byte(flag)
    # if flag != 0x1
    |> put_long(0x5)
    |> put_int()
    |> put_long(0x5)
    |> put_int()
    |> put_long(0x5)
    |> put_int()
  end
end
