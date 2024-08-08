defmodule Ms2ex.Packets.Field do
  import Ms2ex.Packets.PacketWriter

  def put_current_stats(packet, stats) do
    packet
    |> put_byte(0x23)
    |> put_long(stats.health_cur)
    |> put_int(stats.attack_speed_cur)
    |> put_int(stats.movement_speed_cur)
    |> put_int(stats.mount_speed_cur)
    |> put_int(stats.jump_height_cur)
    |> put_long(stats.health_min)
    |> put_int(stats.attack_speed_min)
    |> put_int(stats.movement_speed_min)
    |> put_int(stats.mount_speed_min)
    |> put_int(stats.jump_height_min)
    |> put_long(stats.health_max)
    |> put_int(stats.attack_speed_max)
    |> put_int(stats.movement_speed_max)
    |> put_int(stats.mount_speed_max)
    |> put_int(stats.jump_height_max)
  end
end
