defmodule Ms2ex.Packets.PlayerStats do
  import Ms2ex.Packets.PacketWriter

  @stats [
    # STR 0
    {100, 0, 100},
    # DEX 1
    {100, 0, 100},
    # INT 2
    {100, 0, 100},
    # LUK 3
    {100, 0, 100},
    # HP 4
    {1000, 0, 1000},
    # CURRENT HP 5
    {0, 500, 0},
    # HP REGEN 6
    {100, 0, 100},
    # NA 7
    {100, 0, 100},
    # SPIRIT 8
    {100, 100, 100},
    # NA 9
    {100, 0, 100},
    # NA 10
    {100, 0, 100},
    # STAMINA 11
    {120, 120, 120},
    # NA 12
    {100, 0, 100},
    # NA 13
    {100, 0, 100},
    # ATTK SPD 14
    {120, 1000, 130},
    # MOV SPD 15
    {110, 100, 150},
    # ACCURACY 16
    {100, 0, 100},
    # EVA 17
    {100, 0, 100},
    # CRIT RATE 18
    {100, 0, 100},
    # CRIT DMG 19
    {100, 0, 100},
    # CRIT EVA 20
    {100, 0, 100},
    # DEF 21
    {100, 0, 100},
    # GUARD 22
    {100, 0, 100},
    # JUMP HEIGHT 23
    {110, 100, 130},
    # PHYS ATTK 24
    {100, 0, 100},
    # MAGIC ATTK 25
    {100, 0, 100},
    # PHYS RES 26
    {100, 0, 100},
    # MAG RES 27
    {100, 0, 100},
    # MIN ATTK 28
    {100, 0, 100},
    # MAX ATTK 29
    {100, 0, 100},
    # NA 30
    {100, 0, 100},
    # NA 31
    {100, 0, 100},
    # PIERCE 32
    {100, 0, 100},
    # MOUNT SPEED 33
    {100, 100, 100},
    # BONUS ATTK 34
    {100, 0, 100},
    # NA 35
    {100, 0, 100}
  ]

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte()
    |> put_byte(0x23)
    |> put_stats(@stats)
  end

  defp put_stats(packet, []), do: packet

  defp put_stats(packet, [{total, min, max} | stats]) do
    packet
    |> put_int(total)
    |> put_int(min)
    |> put_int(max)
    |> put_stats(stats)
  end

  def stats(), do: @stats
end
