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
end
