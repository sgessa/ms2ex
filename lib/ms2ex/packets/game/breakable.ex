defmodule Ms2ex.Packets.Breakable do
  import Ms2ex.Packets.PacketWriter

  # commands
  @batch_update 0x0

  @doc """
  Announces the field's breakable objects to a joining player. Breakables
  toggle between shown/hidden/broken states as trigger scripts drive them.
  """
  def load(breakables) do
    update(breakables)
  end

  @doc """
  Applies a state/visible change to a batch of breakable objects. Each entry
  carries the map entity uuid the client knows the object by, plus its state
  byte and visibility.
  """
  def update(entries) do
    now = System.monotonic_time(:millisecond)

    __MODULE__
    |> build()
    |> put_byte(@batch_update)
    |> put_int(length(entries))
    |> then(
      &Enum.reduce(entries, &1, fn entry, packet ->
        packet
        |> put_string(entry.uuid)
        |> put_byte(entry.state)
        |> put_bool(entry.visible)
        |> put_move_ticks(now, Map.get(entry, :base_tick, 0))
      end)
    )
  end

  # moving platforms re-phase their shuttle from this tick pair: a shown
  # platform restarts its move cycle at base_tick, so the pair must carry
  # the real transition time — zeros leave the client on its load-time
  # cycle phase (a shown cart can resume mid-return, riding backwards)
  defp put_move_ticks(packet, _now, 0), do: packet |> put_int(0) |> put_int(0)

  defp put_move_ticks(packet, now, base_tick) do
    # put_int truncates to the low 32 bits, matching the reference
    packet |> put_int(now - base_tick) |> put_int(base_tick)
  end

  def load_empty do
    build(__MODULE__)
    |> put_byte(0x0)
    |> put_int(0)
  end
end
