defmodule Ms2ex.Packets.ResponseRide do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @modes %{start: 0x0, stop: 0x1, change: 0x2}

  def start_ride(character, mount) do
    __MODULE__
    |> build()
    |> put_byte(@modes.start)
    |> put_int(character.object_id)
    |> put_byte(mount.type)
    |> put_int(mount.item_id)
    |> put_int(mount.object_id)
    |> put_mount(mount)
  end

  def stop_ride(character, forced) do
    __MODULE__
    |> build()
    |> put_byte(@modes.stop)
    |> put_int(character.object_id)
    |> put_byte()
    |> put_bool(forced)
  end

  def change_ride(character, item_id, id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.change)
    |> put_int(character.object_id)
    |> put_int(item_id)
    |> put_long(id)
  end

  defp put_mount(packet, %{type: 0x1} = mount) do
    packet
    |> put_int(mount.item_id)
    |> put_long(mount.id)
    |> Packets.UGC.put_ugc()
  end

  defp put_mount(packet, %{type: 0x2}) do
    packet
    |> put_int()
    |> put_short()
  end

  defp put_mount(packet, _mount), do: packet
end
