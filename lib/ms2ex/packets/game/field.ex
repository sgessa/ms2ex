defmodule Ms2ex.Packets.Field do
  import Ms2ex.Packets.PacketWriter

  def put_passive_skills(packet) do
    count = 0

    packet
    |> put_short(count)
    |> put_passive_skill(count)
  end

  defp put_passive_skill(packet, count) when count > 0 do
    packet
    |> put_int(5_963_582)
    |> put_int(34_759_588)
    |> put_int(5_963_582)
    |> put_int(679_834_064)
    |> put_int(679_834_064)
    |> put_int(10_500_111)
    |> put_short(0x1)
    |> put_int(0x1)
    |> put_byte(0x1)
    |> put_long()
    |> put_passive_skill(count - 1)
  end

  defp put_passive_skill(packet, _count), do: packet

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
