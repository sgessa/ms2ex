defmodule Ms2ex.Packets.PlayerStats do
  import Ms2ex.Packets.PacketWriter

  def bytes(character) do
    stat_list = Ms2ex.CharacterStats.fields()

    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte()
    |> put_byte(0x23)
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
    |> put_byte(0x4)
    |> put_long(obj.stats.hp.total)
    |> put_long(obj.stats.hp.min)
    |> put_long(obj.stats.hp.max)
  end
end
