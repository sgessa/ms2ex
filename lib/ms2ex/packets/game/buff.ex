defmodule Ms2ex.Packets.Buff do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    add: 0,
    remove: 1,
    update: 2
  }

  def send(mode, status) do
    __MODULE__
    |> build()
    |> put_byte(Map.get(@modes, mode))
    |> put_int(status.target)
    |> put_int(status.id)
    |> put_int(status.source)
    |> handle_mode(mode, status)
  end

  defp handle_mode(packet, :add, status) do
    packet
    |> put_int(status.start)
    |> put_int(status.end)
    |> put_int(status.skill_cast.skill_id)
    |> put_short(status.skill_cast.skill_level)
    |> put_int(status.stacks)
    |> put_byte(0x1)
    |> put_long()
  end

  defp handle_mode(packet, :remove, _status), do: packet

  defp handle_mode(packet, :update, status) do
    packet
    |> put_int(status.target)
    |> put_int(status.start)
    |> put_int(status.end)
    |> put_int(status.skill_cast.skill_id)
    |> put_short(status.skill_cast.skill_level)
    |> put_int(status.stacks)
    |> put_byte()
  end
end
