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
    {total_hp, min_hp, max_hp} = Enum.at(stats, 4)
    {total_attk_speed, min_attk_speed, max_attk_speed} = Enum.at(stats, 14)
    {total_mov_speed, min_mov_speed, max_mov_speed} = Enum.at(stats, 15)
    {total_mount_speed, min_mount_speed, max_mount_speed} = Enum.at(stats, 33)
    {total_jump_height, min_jump_height, max_jump_height} = Enum.at(stats, 23)

    packet
    |> put_byte(0x23)
    |> put_long(total_hp)
    |> put_int(total_attk_speed)
    |> put_int(total_mov_speed)
    |> put_int(total_mount_speed)
    |> put_int(total_jump_height)
    |> put_long(min_hp)
    |> put_int(min_attk_speed)
    |> put_int(min_mov_speed)
    |> put_int(min_mount_speed)
    |> put_int(min_jump_height)
    |> put_long(max_hp)
    |> put_int(max_attk_speed)
    |> put_int(max_mov_speed)
    |> put_int(max_mount_speed)
    |> put_int(max_jump_height)
  end
end
