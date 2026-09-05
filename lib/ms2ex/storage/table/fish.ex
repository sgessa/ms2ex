defmodule Ms2ex.Storage.Tables.Fish do
  @moduledoc """
  `fish.xml`: the fish catalogue, the fishing spot of each map and the fish
  boxes a spot rolls its catches from.
  """

  alias Ms2ex.Storage

  @table_name "fish.xml"

  @spec spot(integer()) :: {:ok, map()} | :error
  def spot(map_id) do
    fetch([:spots, map_id])
  end

  @spec fish(integer()) :: {:ok, map()} | :error
  def fish(fish_id) do
    fetch([:fishes, fish_id])
  end

  @spec global_box(integer()) :: {:ok, map()} | :error
  def global_box(box_id), do: fetch([:global_fish_boxes, box_id])

  @spec individual_box(integer()) :: {:ok, map()} | :error
  def individual_box(box_id), do: fetch([:individual_fish_boxes, box_id])

  defp fetch(path) do
    :table
    |> Storage.get(@table_name)
    |> get_in(path)
    |> case do
      nil -> :error
      value -> {:ok, value}
    end
  end
end
