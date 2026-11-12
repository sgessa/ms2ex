defmodule Ms2ex.Storage.Pets do
  @moduledoc """
  `pet:<item id>` documents: the per-pet row — npc appearance, bag slots,
  taming ai presets, skill/effects, movement distances, animation timings.

  `pet_npc:<npc id>` documents: the pet item id that renders as this npc —
  npc spawns whose id is a pet's appearance are tameable wild pets.
  """

  alias Ms2ex.Storage

  @spec get_meta(item_id :: integer()) :: map() | nil
  def get_meta(item_id) do
    Storage.get(:pet, item_id)
  end

  @spec pet_id_for_npc(npc_id :: integer()) :: integer() | nil
  def pet_id_for_npc(npc_id) do
    case Storage.get(:pet_npc, npc_id) do
      %{pet_id: pet_id} when is_integer(pet_id) and pet_id > 0 -> pet_id
      _ -> nil
    end
  end
end
