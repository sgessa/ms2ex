defmodule Ms2ex.Packets.ControlNpc do
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketWriter

  def bytes(npcs, boss_target \\ nil) do
    __MODULE__
    |> build()
    |> put_short(length(npcs))
    |> reduce(npcs, fn npc, packet ->
      npc_data = npc_data(npc, boss_target)

      packet
      |> put_short(byte_size(npc_data))
      |> put_bytes(npc_data)
    end)
  end

  # Death announcement: a single entry with flags=0, state=None and seqId=-1;
  # the client plays the death animation. Bosses still carry the target-id
  # slot but it reads zero here, and the sequence counter is the npc's real
  # (incremented) value.
  def dead(%Types.FieldNpc{} = npc) do
    single_entry(npc, 0x0)
  end

  # Hitting a corpse replays a hit animation on the fallen body instead of
  # the death animation.
  def corpse_hit(%Types.FieldNpc{} = npc) do
    single_entry(npc, 13)
  end

  defp single_entry(%Types.FieldNpc{} = npc, state) do
    data =
      ""
      |> put_int(npc.object_id)
      |> put_byte(0x0)
      |> put_short_coord(npc.position)
      |> put_short(trunc(npc.rotation.z * 10))
      |> put_short_coord()
      |> put_short(100)
      |> put_dead_target_id(npc)
      |> put_byte(state)
      |> put_short(-1)
      |> put_short(npc.seq_counter)

    __MODULE__
    |> build()
    |> put_short(1)
    |> put_short(byte_size(data))
    |> put_bytes(data)
  end

  defp npc_data(%Types.FieldNpc{} = npc, boss_target) do
    ""
    |> put_int(npc.object_id)
    # Flags: bit-1 (AdditionalEffectRelated), bit-2 (UIHpBarRelated). The
    # client registers a boss's HP bar from these bits, so they stay set for
    # every alive entry regardless of combat state; only the boss target-id
    # changes when battle begins.
    |> put_byte(0x2)
    |> put_short_coord(npc.position)
    # TODO convert Z to degree
    |> put_short(trunc(npc.rotation.z * 10))
    # speed
    |> put_short_coord()
    |> put_short(100)
    |> put_target_id(npc, boss_target)
    |> put_state(npc)
    |> put_short(npc.animation)
    |> put_short(npc.seq_counter)
  end

  # bosses stay in the PcSkill reaction state while engaged by a player (the
  # client shows the field-boss HP bar for a boss reacting to a player skill);
  # regular mobs idle
  defp put_state(packet, %Types.FieldNpc{npc: %{boss?: true}}), do: put_byte(packet, 16)
  defp put_state(packet, _npc), do: put_byte(packet, 1)

  # bosses carry their current target's object id; a non-zero value tells
  # the client the boss is in battle (drives the boss HP bar UI). Until the
  # boss has been struck, it holds the field's default target (the nearest
  # player), mirroring a freshly-aggroed boss.
  defp put_target_id(packet, %Types.FieldNpc{npc: %{boss?: true}, last_attacker: nil}, nil),
    do: put_int(packet, 0)

  defp put_target_id(
         packet,
         %Types.FieldNpc{npc: %{boss?: true}, last_attacker: nil},
         default_target
       ),
       do: put_int(packet, default_target)

  defp put_target_id(
         packet,
         %Types.FieldNpc{npc: %{boss?: true}, last_attacker: attacker},
         _default
       ),
       do: put_int(packet, attacker.object_id)

  defp put_target_id(packet, _npc, _default), do: packet

  # dead entries always report an idle target, even for bosses
  defp put_dead_target_id(packet, %Types.FieldNpc{npc: %{boss?: true}}) do
    put_int(packet, 0)
  end

  defp put_dead_target_id(packet, _npc), do: packet
end
