defmodule Ms2ex.Packets.Stats do
  alias Ms2ex.Enums
  alias Ms2ex.Packets

  alias Ms2ex.Types.FieldNpc
  import Packets.PacketWriter

  @mode %{update_char_stats: 0x1, send_stats: 0x23, update_mob_health: 0x4}

  def set_character_stats(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte()
    |> put_byte(@mode.send_stats)
    |> put_stats(character.stats)
  end

  def update_char_stats(character, stat) when not is_list(stat) do
    update_char_stats(character, [stat])
  end

  def update_char_stats(character, updated_stats) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte(@mode.update_char_stats)
    |> put_byte(0x1)
    |> reduce(updated_stats, fn
      :health, packet ->
        packet
        |> put_byte(Enums.BasicStatType.get_value(:health))
        |> put_hp(character.stats)

      s, packet ->
        packet
        |> put_byte(Enums.BasicStatType.get_value(s))
        |> put_stat(character.stats, s)
    end)
  end

  def update_mob_stat(%FieldNpc{} = mob, stat) do
    values = mob.stats[stat]

    __MODULE__
    |> build()
    |> put_int(mob.object_id)
    # mode 0x1 = targeted update (same layout as working player updates);
    # mode 0x0 makes this client expect a full 35-stat dump and drop the packet
    |> put_byte(@mode.update_char_stats)
    |> put_byte(0x1)
    |> put_byte(Enums.BasicStatType.get_value(stat))
    # the client reads stat values by index: [Total, Base, Current]
    |> put_long(values.total)
    |> put_long(values.base)
    |> put_long(values.current)
  end

  def put_stats(packet, stats) do
    reduce(packet, Enums.BasicStatType.ordered_keys(), fn
      :health, packet ->
        put_hp(packet, stats)

      stat, packet ->
        put_stat(packet, stats, stat)
    end)
  end

  def put_default_mob_stats(packet, %FieldNpc{} = mob) do
    packet
    |> put_byte(@mode.send_stats)
    |> put_long(mob.stats.health)
    |> put_int(100)
    |> put_long(mob.stats.health)
    |> put_int(100)
    |> put_long(mob.stats.health)
    |> put_int(100)

    # TODO Understand mob hp stats
  end

  defp put_hp(packet, stats) do
    packet
    |> put_long(Map.get(stats, :health_max))
    |> put_long(Map.get(stats, :health_min))
    |> put_long(Map.get(stats, :health_cur))
  end

  defp put_stat(packet, stats, stat) do
    packet
    |> put_int(Map.get(stats, :"#{stat}_max"))
    |> put_int(Map.get(stats, :"#{stat}_min"))
    |> put_int(Map.get(stats, :"#{stat}_cur"))
  end
end
