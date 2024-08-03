defmodule Ms2ex.Packets.ControlNpc do
  alias Ms2ex.Mob

  import Ms2ex.Packets.PacketWriter

  def bytes(type, npc) do
    data = npc_data(type, npc)

    __MODULE__
    |> build()
    |> put_short(0x1)
    |> put_short(byte_size(data))
    |> put_bytes(data)
  end

  defp npc_data(:npc, npc) do
    ""
    |> put_int(npc.object_id)
    # Flags bit-1 (AdditionalEffectRelated), bit-2 (UIHpBarRelated)
    |> put_byte(2)
    |> put_short_coord(npc.position)
    # TODO convert Z to degree
    |> put_short(trunc(npc.rotation.z * 10))
    # speed
    |> put_short_coord()
    |> put_short(100)
    # TODO write battle state if boss
    |> put_byte(0x1)
    |> put_short(npc.animation)
    |> put_short(0x1)
  end

  defp npc_data(:mob, %Mob{boss?: true} = npc) do
    ""
    |> put_int(npc.object_id)
    |> put_byte()
    |> put_short_coord(npc.position)
    |> put_short(npc.rotation.z)
    |> put_short_coord()
    |> put_short(100)
    |> put_int()
    |> put_byte(0x1)
    |> put_short(npc.animation)
    |> put_short(0x1)
  end

  defp npc_data(:mob, %Mob{} = npc) do
    ""
    |> put_int(npc.object_id)
    |> put_byte()
    |> put_short_coord(npc.position)
    |> put_short(npc.rotation.z)
    |> put_short_coord()
    |> put_short(100)
    |> put_byte(0x1)
    |> put_short(npc.animation)
    |> put_short(0x1)
  end
end
