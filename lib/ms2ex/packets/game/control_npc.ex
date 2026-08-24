defmodule Ms2ex.Packets.ControlNpc do
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketWriter

  @actor_state_none 0
  @actor_state_idle 1
  @seq_continue -1

  def bytes(npcs) do
    frame(npcs, fn npc ->
      entry(npc, flags: 0x2, state: @actor_state_idle, seq_id: npc.animation)
    end)
  end

  # Death is announced with a single control entry (flags=0, state None,
  # seqId=-1); the client plays the death animation on its own. Matches
  # NpcControlPacket.Dead in the reference implementation.
  def dead(%Types.FieldNpc{} = npc) do
    frame([npc], fn npc ->
      entry(npc, flags: 0x0, state: @actor_state_none, seq_counter: npc.seq_counter)
    end)
  end

  defp frame(npcs, entry_fn) do
    __MODULE__
    |> build()
    |> put_short(length(npcs))
    |> reduce(npcs, fn npc, packet ->
      data = entry_fn.(npc)

      packet
      |> put_short(byte_size(data))
      |> put_bytes(data)
    end)
  end

  defp entry(%Types.FieldNpc{} = npc, opts) do
    ""
    |> put_int(npc.object_id)
    # Flags bit-1 (AdditionalEffectRelated), bit-2 (UIHpBarRelated)
    |> put_byte(Keyword.fetch!(opts, :flags))
    |> put_short_coord(npc.position)
    # TODO convert Z to degree
    |> put_short(trunc(npc.rotation.z * 10))
    # speed
    |> put_short_coord()
    |> put_short(100)
    |> put_target_id(npc)
    |> put_byte(Keyword.fetch!(opts, :state))
    |> put_short(Keyword.get(opts, :seq_id, @seq_continue))
    |> put_short(Keyword.get(opts, :seq_counter, npc.seq_counter))
  end

  defp put_target_id(packet, %Types.FieldNpc{npc: %{boss?: true}}), do: put_int(packet, 0)
  defp put_target_id(packet, _npc), do: packet
end
