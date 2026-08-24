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

  # Death announcement (mirrors NpcControlPacket.Dead): a single entry with
  # flags=0, state=None and seqId=-1; the client plays the death animation.
  def dead(%Types.FieldNpc{} = npc) do
    data =
      ""
      |> put_int(npc.object_id)
      |> put_byte(0x0)
      |> put_short_coord(npc.position)
      |> put_short(trunc(npc.rotation.z * 10))
      |> put_short_coord()
      |> put_short(100)
      |> put_target_id(npc)
      |> put_byte(0x0)
      |> put_short(-1)
      |> put_short(1)

    __MODULE__
    |> build()
    |> put_short(1)
    |> put_short(byte_size(data))
    |> put_bytes(data)
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
    |> put_short(npc.seq_counter)
  end

  # bosses carry their current target's object id; a non-zero value tells
  # the client the boss is in battle (drives the boss HP bar UI)
  defp put_target_id(packet, %Types.FieldNpc{npc: %{boss?: true}, last_attacker: nil}) do
    put_int(packet, 0)
  end

  defp put_target_id(packet, %Types.FieldNpc{npc: %{boss?: true}, last_attacker: attacker}) do
    put_int(packet, attacker.object_id)
  end

  defp put_target_id(packet, _npc), do: packet
end
