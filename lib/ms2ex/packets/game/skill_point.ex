defmodule Ms2ex.Packets.SkillPoint do
  import Ms2ex.Packets.PacketWriter

  # source id -> %{rank => points}; the client expects every source it knows
  # with both ranks present
  def sources(
        sources \\ %{1 => %{0 => 0, 1 => 0}, 2 => %{0 => 0, 1 => 0}, 3 => %{0 => 0, 1 => 0}}
      ) do
    total =
      sources
      |> Map.values()
      |> Enum.flat_map(&Map.values/1)
      |> Enum.sum()

    __MODULE__
    |> build()
    |> put_int(total)
    |> put_int(map_size(sources))
    |> reduce(sources, fn {source, ranks}, packet ->
      packet
      |> put_int(source)
      |> put_int(map_size(ranks))
      |> reduce(ranks, fn {rank, points}, packet ->
        packet
        |> put_short(rank)
        |> put_int(points)
      end)
    end)
  end
end
