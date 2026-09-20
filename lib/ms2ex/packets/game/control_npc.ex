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
    # client registers a mob's HP bar from these bits, so they stay set for
    # every alive entry regardless of combat state.
    |> put_byte(0x2)
    |> put_short_coord(npc.position)
    # TODO convert Z to degree
    |> put_short(trunc(npc.rotation.z * 10))
    # movement velocity lets the client interpolate between control packets
    |> put_velocity(npc)
    |> put_anim_speed(npc)
    |> put_target_id(npc, boss_target)
    |> put_state(npc)
    |> put_short(npc.animation)
    |> put_short(npc.seq_counter)
  end

  defp put_velocity(packet, %Types.FieldNpc{velocity: {vx, vy, vz}})
       when {vx, vy, vz} != {0, 0, 0} do
    packet
    |> put_short(round(vx))
    |> put_short(round(vy))
    |> put_short(round(vz))
  end

  defp put_velocity(packet, _npc), do: put_short_coord(packet)

  # sequence playback rate (100 = 1.0x): the client scales the played
  # animation by it, so a walk cycle has to ride the gait speed the npc is
  # actually covering ground at — otherwise the model glides over its own
  # stride and the feet never plant on the ground. the rate is the model's
  # ani_speed factor times the current movement speed (x100); a standing
  # npc plays at its bare ani_speed
  defp put_anim_speed(packet, %Types.FieldNpc{} = npc) do
    # a standing npc (zero velocity) plays at its bare ani_speed
    speed = max(velocity_magnitude(npc), 1.0)
    put_short(packet, trunc(ani_speed(npc) * speed * 100))
  end

  defp velocity_magnitude(%Types.FieldNpc{velocity: {vx, vy, vz}}) do
    :math.sqrt(vx * vx + vy * vy + vz * vz)
  end

  defp ani_speed(%Types.FieldNpc{} = npc) do
    case get_in(npc.npc.metadata, [:model, :ani_speed]) do
      rate when is_number(rate) and rate > 0 -> rate
      _ -> 1.0
    end
  end

  # The state byte tells the client which actor state to present. A moving
  # mob reports Walk (2) so the client plays the locomotion animation and
  # interpolates the steps; a mob that is engaged but standing holds the
  # PcSkill reaction (16), which is what arms the field HP bar; otherwise
  # idle (1).
  defp put_state(packet, %Types.FieldNpc{velocity: {vx, vy, _vz}})
       when vx != 0 or vy != 0 do
    put_byte(packet, 2)
  end

  defp put_state(packet, %Types.FieldNpc{battle: battle}) when is_map(battle) do
    put_byte(packet, 16)
  end

  defp put_state(packet, _npc), do: put_byte(packet, 1)

  # bosses carry their current target's object id; a non-zero value tells
  # the client the boss is in battle (drives the boss HP bar UI). While
  # engaged it holds the aggro target's object id; until the boss has been
  # struck (or its target dropped), it holds the field's default target (the
  # nearest player), mirroring a freshly-aggroed boss.
  defp put_target_id(
         packet,
         %Types.FieldNpc{npc: %{boss?: true}, battle: %{target_object_id: oid}},
         _default_target
       )
       when is_integer(oid),
       do: put_int(packet, oid)

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
