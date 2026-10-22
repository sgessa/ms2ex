defmodule Ms2ex.Storage.Pets do
  @moduledoc """
  `pet:<item id>` documents: the per-pet row — npc appearance, bag slots,
  taming ai presets, skill/effects, movement distances, animation timings.
  """

  alias Ms2ex.Storage

  @spec get_meta(item_id :: integer()) :: map() | nil
  def get_meta(item_id) do
    Storage.get(:pet, item_id)
  end
end
