defmodule Ms2ex.Packets.ResponseRide do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @modes %{start: 0x0, stop: 0x1, change: 0x2}

  def start_ride(character, mount) do
    __MODULE__
    |> build()
    |> put_byte(@modes.start)
    |> put_int(character.object_id)
    |> put_byte(mount.mount_type)
    |> put_int(mount.ride_id)
    |> put_int(mount.object_id)
    |> put_action(mount)
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

  defp put_action(packet, mount) do
    packet
    |> put_int(mount.item_id)
    |> put_long(mount.item_uid)
    |> Packets.UGC.put_ugc()
  end
end
