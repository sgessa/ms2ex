defmodule Ms2ex.Packets.Stats do
  alias Ms2ex.{Enums, Mob, Packets}

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
      :hp, packet ->
        packet
        |> put_byte(Enums.StatId.get_value(:hp))
        |> put_hp(character.stats)

      s, packet ->
        packet
        |> put_byte(Enums.StatId.get_value(s))
        |> put_stat(character.stats, s)
    end)
  end

  def update_mob_health(%Mob{} = mob) do
    __MODULE__
    |> build()
    |> put_int(mob.object_id)
    |> put_byte()
    |> put_byte(0x1)
    |> put_byte(@mode.update_mob_health)
    |> put_long(mob.stats.hp.bonus)
    |> put_long(mob.stats.hp.base)
    |> put_long(mob.stats.hp.total)
  end

  def put_stats(packet, stats) do
    reduce(packet, Enums.StatId.ordered(), fn
      :hp, packet ->
        put_hp(packet, stats)

      stat, packet ->
        put_stat(packet, stats, stat)
    end)
  end

  def put_default_mob_stats(packet, %Mob{} = mob) do
    packet
    |> put_byte(@mode.send_stats)
    |> put_long(mob.stats.hp.bonus)
    |> put_int(100)
    |> put_long(mob.stats.hp.base)
    |> put_int(100)
    |> put_long(mob.stats.hp.total)
    |> put_int(100)
  end

  defp put_hp(packet, stats) do
    packet
    |> put_long(Map.get(stats, :hp_max))
    |> put_long(Map.get(stats, :hp_min))
    |> put_long(Map.get(stats, :hp_cur))
  end

  defp put_stat(packet, stats, stat) do
    packet
    |> put_int(Map.get(stats, :"#{stat}_max"))
    |> put_int(Map.get(stats, :"#{stat}_min"))
    |> put_int(Map.get(stats, :"#{stat}_cur"))
  end
end
