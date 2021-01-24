defmodule Ms2ex.Packets.Job do
  import Ms2ex.Packets.PacketWriter

  @skill_ids [
    10_500_101,
    10_500_152,
    10_500_221,
    10_500_051,
    10_500_153,
    10_500_171,
    10_500_001,
    10_500_291,
    10_500_172,
    10_500_241,
    20_000_011,
    10_500_173,
    10_500_191,
    10_500_021,
    10_500_174,
    10_500_141,
    10_500_192,
    10_500_243,
    10_500_091,
    10_500_193,
    10_500_261,
    10_500_041,
    10_500_211,
    10_500_093,
    10_500_144,
    10_500_281,
    10_500_231,
    20_000_001,
    10_500_061,
    10_500_181,
    10_500_011,
    10_500_081,
    10_500_031,
    10_500_065,
    10_500_151,
    10_500_067,
    10_500_271,
    10_500_121,
    10_500_292,
    10_500_071,
    10_500_293,
    10_500_161,
    10_500_111,
    10_500_232,
    10_500_131,
    10_500_063,
    10_500_251,
    10_500_064,
    10_500_201
  ]

  def put_skills(packet, _character) do
    split = 14
    count_id = Enum.at(@skill_ids, length(@skill_ids) - split)

    packet
    |> put_tiny(length(@skill_ids) - split)
    |> reduce(@skill_ids, fn skill_id, packet ->
      packet = if skill_id == count_id, do: put_tiny(packet, split), else: packet

      packet
      |> put_byte()
      |> put_tiny(0x0)
      |> put_int(skill_id)
      |> put_int(0x1)
      |> put_byte()
    end)
    |> put_short()
  end
end
