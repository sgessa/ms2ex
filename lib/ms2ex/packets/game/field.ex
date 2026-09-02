defmodule Ms2ex.Packets.Field do
  import Ms2ex.Packets.PacketWriter

  def put_current_stats(packet, stats) do
    packet
    |> put_byte(0x23)
    |> put_stat_row(stats, :max)
    |> put_stat_row(stats, :min)
    |> put_stat_row(stats, :cur)
  end

  defp put_stat_row(packet, stats, suffix) do
    packet
    |> put_long(Map.fetch!(stats, :"health_#{suffix}"))
    |> put_int(Map.fetch!(stats, :"attack_speed_#{suffix}"))
    |> put_int(Map.fetch!(stats, :"movement_speed_#{suffix}"))
    |> put_int(Map.fetch!(stats, :"jump_height_#{suffix}"))
    |> put_int(Map.fetch!(stats, :"mount_speed_#{suffix}"))
  end
end
