defmodule Ms2ex.Packets.Stats do
  alias Ms2ex.{CharacterStats, Packets}

  import Packets.PacketWriter

  @mode %{set_char_stats: 0x23, update_npc_stat: 0x4}

  def set_character_stats(character) do
    stat_list = CharacterStats.fields()

    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte()
    |> put_byte(@mode.set_char_stats)
    |> reduce(stat_list, fn stat, packet ->
      put_int(packet, Map.get(character.stats, stat))
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
end
