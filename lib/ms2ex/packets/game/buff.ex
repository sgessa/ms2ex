defmodule Ms2ex.Packets.Buff do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    add: 0,
    remove: 1,
    update: 2
  }

  def send(mode, buff) do
    __MODULE__
    |> build()
    |> put_byte(Map.get(@modes, mode))
    |> put_int(buff.owner.object_id)
    |> put_int(buff.object_id)
    |> put_int(buff.caster.object_id)
    |> handle_mode(mode, buff)
  end

  defp handle_mode(packet, :add, buff) do
    packet
    |> put_int(buff.start_tick)
    |> put_int(buff.end_tick)
    |> put_int(buff.skill[:id])
    |> put_short(buff.skill[:level])
    |> put_int(buff.stacks)
    |> put_bool(buff.enabled)
    |> put_long(trunc(buff.shield_health))
  end

  defp handle_mode(packet, :remove, _status), do: packet

  defp handle_mode(packet, :update, buff) do
    # BuffFlag: UpdateBuff | UpdateShield
    packet
    |> put_int(0x3)
    |> put_int(buff.start_tick)
    |> put_int(buff.end_tick)
    |> put_int(buff.skill[:id])
    |> put_short(buff.skill[:level])
    |> put_int(buff.stacks)
    |> put_bool(buff.enabled)
    |> put_long(trunc(buff.shield_health))
  end
end
