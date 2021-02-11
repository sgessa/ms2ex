defmodule Ms2ex.Packets.ControlNpc do
  import Ms2ex.Packets.PacketWriter

  def bytes(npc) do
    data = npc_data(npc)

    __MODULE__
    |> build()
    |> put_short(0x1)
    |> put_short(byte_size(data))
    |> put_bytes(data)
  end

  defp npc_data(npc) do
    ""
    |> put_int(npc.object_id)
    |> put_byte()
    |> put_short_coord(npc.position)
    |> put_short(npc.direction)
    |> put_short_coord(npc.speed)
    |> put_short(100)
    |> put_byte(0x1)
    |> put_short(npc.animation)
    |> put_short(0x1)
  end
end
