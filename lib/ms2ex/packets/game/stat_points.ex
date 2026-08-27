defmodule Ms2ex.Packets.StatPoints do
  import Ms2ex.Packets.PacketWriter

  @sources 0x0
  @allocation 0x1

  # source id -> points earned (trophy/exploration/prestige)
  def sources(sources \\ %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}) do
    total = sources |> Map.values() |> Enum.sum()

    __MODULE__
    |> build()
    |> put_byte(@sources)
    |> put_int(total)
    |> put_int(map_size(sources))
    |> reduce(sources, fn {source, amount}, packet ->
      packet
      |> put_int(source)
      |> put_int(amount)
    end)
  end

  # attribute id -> points allocated
  def allocation(allocated \\ %{}) do
    total = allocated |> Map.values() |> Enum.sum()

    __MODULE__
    |> build()
    |> put_byte(@allocation)
    |> put_int(total)
    |> put_int(map_size(allocated))
    |> reduce(allocated, fn {attribute, amount}, packet ->
      packet
      |> put_int(attribute)
      |> put_int(amount)
    end)
  end
end
