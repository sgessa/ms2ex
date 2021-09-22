defmodule Ms2ex.Packets.Stats do
  alias Ms2ex.{Packets, StatId}

  import Packets.PacketWriter

  @mode %{update: 0x1, set_char_stats: 0x23, update_npc_stat: 0x4}

  def set_character_stats(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte()
    |> put_byte(@mode.set_char_stats)
    |> put_stats(character.stats)
  end

  def update(character, stats, updated_stats) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte(@mode.update)
    |> put_byte(0x1)
    |> reduce(updated_stats, fn
      :hp, packet ->
        packet
        |> put_byte(StatId.from_name(:hp))
        |> put_hp(stats)

      s, packet ->
        packet
        |> put_byte(StatId.from_name(s))
        |> put_stat(stats, s)
    end)
  end

  def update_health(obj) do
    __MODULE__
    |> build()
    |> put_int(obj.object_id)
    |> put_byte()
    |> put_byte(0x1)
    |> put_byte(@mode.update_npc_stat)
    |> put_long(obj.stats.hp.total)
    |> put_long(obj.stats.hp.min)
    |> put_long(obj.stats.hp.max)
  end

  def put_stats(packet, stats) do
    reduce(packet, StatId.list(), fn
      :hp, packet ->
        put_hp(packet, stats)

      stat, packet ->
        put_stat(packet, stats, stat)
    end)
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
