defmodule Ms2ex.Packets.MassiveEvent do
  import Ms2ex.Packets.PacketWriter

  # event/minigame UI overlays driven by trigger scripts: round indicators,
  # text banners and countdowns
  @round 0
  @countdown 1
  @banner 2

  # rounds = [current, max, min]; the script skips nothing here — the
  # min==max no-op is the caller's decision
  def round(round, max_round, min_round, vertical_offset) do
    __MODULE__
    |> build()
    |> put_byte(@round)
    |> put_int(round)
    |> put_int(max_round)
    |> put_int(min_round)
    |> put_int(vertical_offset)
  end

  def countdown(text, round, seconds) do
    __MODULE__
    |> build()
    |> put_byte(@countdown)
    |> put_ustring(text)
    |> put_int(round)
    |> put_int(seconds)
    |> put_int(1)
  end

  # type follows the client's banner table (0 lose, 1 game over, 2 winner,
  # 3 bonus, 4 draw, 5 success, 6 text, 7 fail, 8 countdown)
  def banner(type, text, duration) do
    __MODULE__
    |> build()
    |> put_byte(@banner)
    |> put_byte(type)
    |> put_ustring(text)
    |> put_int(duration)
  end
end
