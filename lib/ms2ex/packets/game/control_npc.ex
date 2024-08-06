defmodule Ms2ex.Packets.ControlNpc do
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketWriter

  def bytes(npcs) do
    __MODULE__
    |> build()
    |> put_short(length(npcs))
    |> reduce(npcs, fn npc, packet ->
      npc_data = npc_data(npc)

      packet
      |> put_short(byte_size(npc_data))
      |> put_bytes(npc_data)
    end)
  end

  defp npc_data(%Types.FieldNpc{} = npc) do
    ""
    |> put_int(npc.object_id)
    # Flags bit-1 (AdditionalEffectRelated), bit-2 (UIHpBarRelated)
    |> put_byte(0x2)
    |> put_short_coord(npc.position)
    # TODO convert Z to degree
    |> put_short(trunc(npc.rotation.z * 10))
    # speed
    |> put_short_coord()
    |> put_short(100)
    |> put_target_id(npc)
    |> put_byte(0x1)
    |> put_short(npc.animation)
    |> put_short(0x1)
  end

  defp put_target_id(packet, %Types.Npc{boss?: true}) do
    # ObjectId of Player being targeted?
    put_int(packet)
  end

  defp put_target_id(packet, _npc), do: packet
end
