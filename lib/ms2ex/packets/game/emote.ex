defmodule Ms2ex.Packets.Emote do
  import Ms2ex.Packets.PacketWriter

  @emotes [
    90_200_011,
    90_200_004,
    90_200_024,
    90_200_041,
    90_200_042,
    90_200_057,
    90_200_043,
    90_200_022,
    90_200_031,
    90_200_005,
    90_200_006,
    90_200_003,
    90_200_092,
    90_200_077,
    90_200_073,
    90_200_023,
    90_200_001,
    90_200_019,
    90_200_020,
    90_200_021,
    90_200_009,
    90_200_027,
    90_200_010,
    90_200_028,
    90_200_051,
    90_200_015,
    90_200_016,
    90_200_055,
    90_200_060,
    90_200_017,
    90_200_018,
    90_200_093,
    90_220_033,
    90_220_012,
    90_220_001,
    90_220_033
  ]

  @modes %{load: 0x0, learn: 0x1}

  def load() do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_int(length(@emotes))
    |> reduce(@emotes, fn emote_id, packet ->
      packet
      |> put_int(emote_id)
      |> put_int(0x1)
      |> put_long(0x0)
    end)
  end

  def learn(emote_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.learn)
    |> put_int(emote_id)
    |> put_int()
    |> put_long()
  end
end
