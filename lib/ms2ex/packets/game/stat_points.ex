defmodule Ms2ex.Packets.StatPoints do
  alias Ms2ex.Context.StatPoints
  alias Ms2ex.Types.AttributePointSource

  import Ms2ex.Packets.PacketWriter

  @sources 0x0
  @allocation 0x1

  @doc """
  Sends the AP source totals. Triggers the "Received AP" in-game notification.
  `sources` is an atom-keyed map, e.g. `%{trophy: 5, command: 10, ...}`.
  """
  def sources(sources) do
    sources = AttributePointSource.normalize(sources)
    total = sources |> Map.values() |> Enum.sum()

    # sort by wire ID so packet order is stable
    sorted =
      Enum.sort_by(sources, fn {src, _} -> AttributePointSource.get_value(src) end)

    __MODULE__
    |> build()
    |> put_byte(@sources)
    |> put_int(total)
    |> put_int(length(sorted))
    |> reduce(sorted, fn {src, amount}, packet ->
      packet
      |> put_int(AttributePointSource.get_value(src))
      |> put_int(amount)
    end)
  end

  @doc """
  Sends the current AP allocation state.
  `allocated` is an atom-keyed map, e.g. `%{strength: 3, health: 2}`.
  `total` is the total available points (sum of all sources).
  """
  def allocation(allocated, total) do
    allocated = StatPoints.normalize_allocation(allocated)

    sorted =
      Enum.sort_by(allocated, fn {attr, _} -> StatPoints.attribute_id(attr) end)

    __MODULE__
    |> build()
    |> put_byte(@allocation)
    |> put_int(total)
    |> put_int(length(sorted))
    |> reduce(sorted, fn {attr, amount}, packet ->
      packet
      |> put_byte(StatPoints.attribute_id(attr))
      |> put_int(amount)
    end)
  end
end
