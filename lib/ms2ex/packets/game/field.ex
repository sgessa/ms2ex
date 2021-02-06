defmodule Ms2ex.Packets.Field do
  import Ms2ex.Packets.PacketWriter

  def put_total_stats(packet, stats) do
    packet
    |> put_byte(0x23)
    |> put_long(stats.hp_total)
    |> put_int(stats.attk_speed_total)
    |> put_int(stats.mov_speed_total)
    |> put_int(stats.mount_speed_total)
    |> put_int(stats.jump_height_total)
    |> put_long(stats.hp_min)
    |> put_int(stats.attk_speed_min)
    |> put_int(stats.mov_speed_min)
    |> put_int(stats.mount_speed_min)
    |> put_int(stats.jump_height_min)
    |> put_long(stats.hp_max)
    |> put_int(stats.attk_speed_max)
    |> put_int(stats.mov_speed_max)
    |> put_int(stats.mount_speed_max)
    |> put_int(stats.jump_height_max)
  end
end
